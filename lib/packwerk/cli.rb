# typed: strict
# frozen_string_literal: true

require "optparse"

module Packwerk
  # A command-line interface to Packwerk.
  class Cli
    extend T::Sig

    sig do
      params(
        configuration: T.nilable(Configuration),
        out: T.any(StringIO, IO),
        err_out: T.any(StringIO, IO),
        environment: String,
        style: Packwerk::OutputStyle,
        offenses_formatter: T.nilable(Packwerk::OffensesFormatter)
      ).void
    end
    def initialize(
      configuration: nil,
      out: $stdout,
      err_out: $stderr,
      environment: "test",
      style: OutputStyles::Plain.new,
      offenses_formatter: nil
    )
      @out = out
      @err_out = err_out
      @environment = environment
      @style = style
      @configuration = T.let(configuration || Configuration.from_path, Configuration)
      @progress_formatter = T.let(Formatters::ProgressFormatter.new(@out, style: style), Formatters::ProgressFormatter)
      @offenses_formatter = T.let(
        offenses_formatter || Formatters::OffensesFormatter.new(style: @style),
        OffensesFormatter
      )
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
        output_result(parse_run(args).check)
      when "detect-stale-violations"
        output_result(parse_run(args).detect_stale_violations)
      when "update-deprecations"
        warning = <<~WARNING.squish
          DEPRECATION WARNING: `update-deprecations` is deprecated in favor of
          `update-todo`.
        WARNING

        warn(warning)
        output_result(parse_run(args).update_todo)
      when "update-todo"
        output_result(parse_run(args).update_todo)
      when "update"
        output_result(parse_run(args).update_todo)
      when "validate"
        validate(args)
      when nil, "help"
        @err_out.puts(<<~USAGE)
          Usage: #{$PROGRAM_NAME} <subcommand>

          Subcommands:
            init - set up packwerk
            check - run all checks
            update-todo - update package_todo.yml files
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

    sig { returns(T::Boolean) }
    def init
      @out.puts("📦 Initializing Packwerk...")

      generate_configs
    end

    sig { returns(T::Boolean) }
    def generate_configs
      configuration_file = Packwerk::Generators::ConfigurationFile.generate(
        root: @configuration.root_path,
        out: @out
      )

      root_package = Packwerk::Generators::RootPackage.generate(root: @configuration.root_path, out: @out)

      success = configuration_file && root_package

      result = if success
        <<~EOS

          🎉 Packwerk is ready to be used. You can start defining packages and run `bin/packwerk check`.
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

    sig { params(result: Result).returns(T::Boolean) }
    def output_result(result)
      @out.puts
      @out.puts(result.message)
      result.status
    end

    sig do
      params(
        relative_file_paths: T::Array[String],
        ignore_nested_packages: T::Boolean
      ).returns(FilesForProcessing::RelativeFileSet)
    end
    def fetch_files_to_process(relative_file_paths, ignore_nested_packages)
      relative_file_set = FilesForProcessing.fetch(
        relative_file_paths: relative_file_paths,
        ignore_nested_packages: ignore_nested_packages,
        configuration: @configuration
      )
      abort("No files found or given. "\
        "Specify files or check the include and exclude glob in the config file.") if relative_file_set.empty?
      relative_file_set
    end

    sig { params(_paths: T::Array[String]).returns(T::Boolean) }
    def validate(_paths)
      @progress_formatter.started_validation do
        result = checker.check_all

        list_validation_errors(result)

        return result.ok?
      end
    end

    sig { returns(ApplicationValidator) }
    def checker
      Packwerk::ApplicationValidator.new(
        config_file_path: @configuration.config_path,
        configuration: @configuration,
        environment: @environment,
      )
    end

    sig { params(result: ApplicationValidator::Result).void }
    def list_validation_errors(result)
      @out.puts
      if result.ok?
        @out.puts("Validation successful 🎉")
      else
        @out.puts("Validation failed ❗")
        @out.puts(result.error_value)
      end
    end

    sig { params(params: T.untyped).returns(ParseRun) }
    def parse_run(params)
      relative_file_paths = T.let([], T::Array[String])
      ignore_nested_packages = nil

      if params.any? { |p| p.include?("--packages") }
        OptionParser.new do |parser|
          parser.on("--packages=PACKAGESLIST", Array, "package names, comma separated") do |p|
            relative_file_paths = p
          end
        end.parse!(params)
        ignore_nested_packages = true
      else
        relative_file_paths = params
        ignore_nested_packages = false
      end

      ParseRun.new(
        relative_file_set: fetch_files_to_process(relative_file_paths, ignore_nested_packages),
        configuration: @configuration,
        progress_formatter: @progress_formatter,
        offenses_formatter: @offenses_formatter
      )
    end
  end
end
