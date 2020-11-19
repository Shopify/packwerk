# typed: true
# frozen_string_literal: true
require "benchmark"
require "sorbet-runtime"

require "packwerk/application_validator"
require "packwerk/configuration"
require "packwerk/files_for_processing"
require "packwerk/formatters/progress_formatter"
require "packwerk/inflector"
require "packwerk/output_styles"
require "packwerk/run_context"
require "packwerk/updating_deprecated_references"
require "packwerk/checking_deprecated_references"
require "packwerk/commands/detect_stale_violations_command"
require "packwerk/commands/generate_configs_command"
require "packwerk/commands/init_command"
require "packwerk/commands/offense_progress_marker"

module Packwerk
  class Cli
    extend T::Sig
    include OffenseProgressMarker

    def initialize(run_context: nil, configuration: nil, out: $stdout, err_out: $stderr, style: OutputStyles::Plain)
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
      init = InitCommand.new(out: @out, configuration: @configuration)
      result = init.run
      result.status
    end

    def generate_configs
      generate_configs = GenerateConfigsCommand.new(out: @out, configuration: @configuration)
      result = generate_configs.run
      result.status
    end

    def update(paths)
      warn("`packwerk update` is deprecated in favor of `packwerk update-deprecations`.")
      update_deprecations(paths)
    end

    def update_deprecations(paths)
      updating_deprecated_references = ::Packwerk::UpdatingDeprecatedReferences.new(@configuration.root_path)
      @run_context = Packwerk::RunContext.from_configuration(
        @configuration,
        reference_lister: updating_deprecated_references
      )

      files = fetch_files_to_process(paths)

      @progress_formatter.started(files)

      all_offenses = T.let([], T.untyped)
      execution_time = Benchmark.realtime do
        all_offenses = files.flat_map do |path|
          @run_context.process_file(file: path).tap do |offenses|
            mark_progress(offenses: offenses, progress_formatter: @progress_formatter)
          end
        end

        updating_deprecated_references.dump_deprecated_references_files
      end

      @out.puts # put a new line after the progress dots
      show_offenses(all_offenses)
      @progress_formatter.finished(execution_time)
      @out.puts("✅ `deprecated_references.yml` has been updated.")

      all_offenses.empty?
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

      @out.puts # put a new line after the progress dots
      show_offenses(all_offenses)
      @progress_formatter.finished(execution_time)

      all_offenses.empty?
    end

    def detect_stale_violations(paths)
      detect_stale_violations = DetectStaleViolationsCommand.new(
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

    def show_offenses(offenses)
      if offenses.empty?
        @out.puts("No offenses detected 🎉")
      else
        offenses.each do |offense|
          @out.puts(offense.to_s(@style))
        end

        offenses_string = Inflector.default.pluralize("offense", offenses.length)
        @out.puts("#{offenses.length} #{offenses_string} detected")
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
  end
end
