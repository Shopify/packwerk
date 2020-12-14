# typed: true
# frozen_string_literal: true
require "benchmark"
require "sorbet-runtime"

require "packwerk/application_load_paths"
require "packwerk/application_validator"
require "packwerk/configuration"
require "packwerk/files_for_processing"
require "packwerk/formatters/offenses_formatter"
require "packwerk/formatters/progress_formatter"
require "packwerk/inflector"
require "packwerk/output_style"
require "packwerk/output_styles/plain"
require "packwerk/run_context"
require "packwerk/updating_deprecated_references"
require "packwerk/checking_deprecated_references"
require "packwerk/commands/detect_stale_violations_command"
require "packwerk/commands/update_deprecations_command"
require "packwerk/commands/offense_progress_marker"

module Packwerk
  class Cli
    extend T::Sig
    include OffenseProgressMarker

    sig do
      params(
        run_context: T.nilable(Packwerk::RunContext),
        configuration: T.nilable(Configuration),
        out: T.any(StringIO, IO),
        err_out: T.any(StringIO, IO),
        style: Packwerk::OutputStyle
      ).void
    end
    def initialize(run_context: nil, configuration: nil, out: $stdout, err_out: $stderr, style: OutputStyles::Plain.new)
      @out = out
      @err_out = err_out
      @style = style
      @configuration = configuration || Configuration.from_path
      @run_context = run_context || Packwerk::RunContext.from_configuration(
        @configuration,
        reference_lister: ::Packwerk::CheckingDeprecatedReferences.new(@configuration.root_path),
      )
      @progress_formatter = Formatters::ProgressFormatter.new(@out, style: style)
    end

    sig { params(args: T::Array[String]).returns(T.noreturn) }
    def run(args)
      success = execute_command(args)
      exit(success)
    end

    sig { params(args: T::Array[String]).returns(T::Boolean) }
    def execute_command(args)
      subcommand = args.shift
      case subcommand
      when "init"
        init
      when "generate_configs"
        generate_configs
      when "check"
        check(args)
      when "detect-stale-violations"
        detect_stale_violations(args)
      when "update"
        update(args)
      when "update-deprecations"
        update_deprecations(args)
      when "validate"
        validate(args)
      when nil, "help"
        @err_out.puts(<<~USAGE)
          Usage: #{$PROGRAM_NAME} <subcommand>

          Subcommands:
            init - set up packwerk
            check - run all checks
            update - update deprecated references (deprecated, use update-deprecations instead)
            update-deprecations - update deprecated references
            validate - verify integrity of packwerk and package configuration
            help  - display help information about packwerk
        USAGE
        true
      else
        @err_out.puts("'#{subcommand}' is not a packwerk command. See `packwerk help`.")
        false
      end
    end

    private

    def init
      @out.puts("📦 Initializing Packwerk...")

      application_validation = Packwerk::Generators::ApplicationValidation.generate(
        for_rails_app: rails_app?,
        root: @configuration.root_path,
        out: @out
      )

      if application_validation
        if rails_app?
          # To run in the same space as the Rails process,
          # in order to fetch load paths for the configuration generator
          exec("bin/packwerk", "generate_configs")
        else
          generate_configurations = generate_configs
        end
      end

      application_validation && generate_configurations
    end

    def generate_configs
      configuration_file = Packwerk::Generators::ConfigurationFile.generate(
        load_paths: Packwerk::ApplicationLoadPaths.extract_relevant_paths,
        root: @configuration.root_path,
        out: @out
      )
      inflections_file = Packwerk::Generators::InflectionsFile.generate(root: @configuration.root_path, out: @out)
      root_package = Packwerk::Generators::RootPackage.generate(root: @configuration.root_path, out: @out)

      success = configuration_file && inflections_file && root_package

      result = if success
        <<~EOS

          🎉 Packwerk is ready to be used. You can start defining packages and run `packwerk check`.
          For more information on how to use Packwerk, see: https://github.com/Shopify/packwerk/blob/main/USAGE.md
        EOS
      else
        <<~EOS

          ⚠️  Packwerk is not ready to be used.
          Please check output and refer to https://github.com/Shopify/packwerk/blob/main/USAGE.md for more information.
        EOS
      end

      @out.puts(result)
      success
    end

    def update(paths)
      warn("`packwerk update` is deprecated in favor of `packwerk update-deprecations`.")
      update_deprecations(paths)
    end

    def update_deprecations(paths)
      update_deprecations = Commands::UpdateDeprecationsCommand.new(
        files: fetch_files_to_process(paths),
        configuration: @configuration,
        offenses_formatter: offenses_formatter,
        progress_formatter: @progress_formatter
      )
      result = update_deprecations.run
      @out.puts
      @out.puts(result.message)
      result.status
    end

    def check(paths)
      files = fetch_files_to_process(paths)

      @progress_formatter.started(files)

      all_offenses = T.let([], T.untyped)
      execution_time = Benchmark.realtime do
        files.each do |path|
          @run_context.process_file(file: path).tap do |offenses|
            mark_progress(offenses: offenses, progress_formatter: @progress_formatter)
            all_offenses.concat(offenses)
          end
        end
      rescue Interrupt
        @out.puts
        @out.puts("Manually interrupted. Violations caught so far are listed below:")
      end

      @progress_formatter.finished(execution_time)
      @out.puts
      @out.puts(offenses_formatter.show_offenses(all_offenses))

      all_offenses.empty?
    end

    def detect_stale_violations(paths)
      detect_stale_violations = Commands::DetectStaleViolationsCommand.new(
        files: fetch_files_to_process(paths),
        configuration: @configuration,
        progress_formatter: @progress_formatter
      )
      result = detect_stale_violations.run
      @out.puts
      @out.puts(result.message)
      result.status
    end

    def fetch_files_to_process(paths)
      files = FilesForProcessing.fetch(paths: paths, configuration: @configuration)
      abort("No files found or given. "\
        "Specify files or check the include and exclude glob in the config file.") if files.empty?
      files
    end

    def validate(_paths)
      warn("`packwerk validate` should be run within the application. "\
        "Generate the bin script using `packwerk init` and"\
        " use `bin/packwerk validate` instead.") unless defined?(::Rails)

      @progress_formatter.started_validation do
        checker = Packwerk::ApplicationValidator.new(
          config_file_path: @configuration.config_path,
          configuration: @configuration
        )
        result = checker.check_all

        list_validation_errors(result)

        return result.ok?
      end
    end

    def list_validation_errors(result)
      @out.puts
      if result.ok?
        @out.puts("Validation successful 🎉")
      else
        @out.puts("Validation failed ❗")
        @out.puts(result.error_value)
      end
    end

    sig { returns(T::Boolean) }
    def rails_app?
      if File.exist?("config/application.rb") && File.exist?("bin/rails")
        File.foreach("Gemfile").any? { |line| line.match?(/['"]rails['"]/) }
      else
        false
      end
    end

    def offenses_formatter
      @offenses_formatter ||= Formatters::OffensesFormatter.new(style: @style)
    end
  end
end
