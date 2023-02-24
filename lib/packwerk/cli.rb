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
        style: OutputStyle,
        offenses_formatter: T.nilable(OffensesFormatter)
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
        offenses_formatter || @configuration.offenses_formatter,
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
      when "check"
        output_result(parse_run(args).check)
      when "update-todo", "update"
        output_result(parse_run(args).update_todo)
      when "validate"
        validate(args)
      when "version"
        @out.puts(Packwerk::VERSION)
        true
      when nil, "help"
        usage
      else
        @err_out.puts(
          "'#{subcommand}' is not a packwerk command. See `packwerk help`."
        )
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
      configuration_file = Generators::ConfigurationFile.generate(
        root: @configuration.root_path,
        out: @out
      )

      root_package = Generators::RootPackage.generate(root: @configuration.root_path, out: @out)

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

    sig { returns(T::Boolean) }
    def usage
      @err_out.puts(<<~USAGE)
        Usage: #{$PROGRAM_NAME} <subcommand>

        Subcommands:
          init - set up packwerk
          check - run all checks
          update-todo - update package_todo.yml files
          validate - verify integrity of packwerk and package configuration
          version - output packwerk version
          help  - display help information about packwerk
      USAGE
      true
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
      ).returns(FilesForProcessing)
    end
    def fetch_files_to_process(relative_file_paths, ignore_nested_packages)
      files_for_processing = FilesForProcessing.fetch(
        relative_file_paths: relative_file_paths,
        ignore_nested_packages: ignore_nested_packages,
        configuration: @configuration
      )
      @out.puts(<<~MSG.squish) if files_for_processing.files.empty?
        No files found or given.
        Specify files or check the include and exclude glob in the config file.
      MSG

      files_for_processing
    end

    sig { params(_paths: T::Array[String]).returns(T::Boolean) }
    def validate(_paths)
      result = T.let(nil, T.nilable(Validator::Result))

      @progress_formatter.started_validation do
        result = validator.check_all(package_set, @configuration)

        list_validation_errors(result)
      end

      T.must(result).ok?
    end

    sig { returns(ApplicationValidator) }
    def validator
      ApplicationValidator.new
    end

    sig { returns(PackageSet) }
    def package_set
      PackageSet.load_all_from(
        @configuration.root_path,
        package_pathspec: @configuration.package_paths
      )
    end

    sig { params(result: Validator::Result).void }
    def list_validation_errors(result)
      @out.puts
      if result.ok?
        @out.puts("Validation successful 🎉")
      else
        @out.puts("Validation failed ❗")
        @out.puts
        @out.puts(result.error_value)
      end
    end

    sig { params(args: T::Array[String]).returns(ParseRun) }
    def parse_run(args)
      relative_file_paths = T.let([], T::Array[String])
      ignore_nested_packages = nil
      formatter = @offenses_formatter

      if args.any? { |arg| arg.include?("--packages") }
        OptionParser.new do |parser|
          parser.on("--packages=PACKAGESLIST", Array, "package names, comma separated") do |p|
            relative_file_paths = p
          end
        end.parse!(args)
        ignore_nested_packages = true
      else
        relative_file_paths = args
        ignore_nested_packages = false
      end

      if args.any? { |arg| arg.include?("--offenses-formatter") }
        OptionParser.new do |parser|
          parser.on("--offenses-formatter=FORMATTER", String,
            "identifier of offenses formatter to use") do |formatter_identifier|
            formatter = OffensesFormatter.find(formatter_identifier)
          end
        end.parse!(args)
      end

      files_for_processing = fetch_files_to_process(relative_file_paths, ignore_nested_packages)

      ParseRun.new(
        relative_file_set: files_for_processing.files,
        file_set_specified: files_for_processing.files_specified?,
        configuration: @configuration,
        progress_formatter: @progress_formatter,
        offenses_formatter: formatter
      )
    end
  end
end
