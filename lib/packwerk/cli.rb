# typed: strict
# frozen_string_literal: true

require "optparse"

module Packwerk
  # A command-line interface to Packwerk.
  class Cli
    extend T::Sig
    extend ActiveSupport::Autoload

    autoload :CheckCommand
    autoload :HelpCommand
    autoload :InitCommand
    autoload :UpdateCommand
    autoload :ValidateCommand
    autoload :VersionCommand
    autoload :Result

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
        result = InitCommand.new(out: @out, configuration: @configuration).run
        output_result(result)
      when "check"
        result = CheckCommand.new(parse_run: parse_run(args)).run
        output_result(result)
      when "update-todo", "update"
        result = UpdateCommand.new(parse_run: parse_run(args)).run
        output_result(result)
      when "validate"
        result = ValidateCommand.new(
          configuration: @configuration,
          progress_formatter: @progress_formatter,
        ).run
        output_result(result)
      when "version"
        result = VersionCommand.new.run
        output_result(result)
      when nil, "help"
        result = HelpCommand.new.run
        output_result(result)
      else
        @err_out.puts(
          "'#{subcommand}' is not a packwerk command. See `packwerk help`."
        )
        false
      end
    end

    private

    sig { params(result: Result).returns(T::Boolean) }
    def output_result(result)
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


    sig { params(args: T::Array[String]).returns(ParseRun) }
    def parse_run(args)
      relative_file_paths = T.let([], T::Array[String])
      ignore_nested_packages = T.let(false, T::Boolean)
      formatter = @offenses_formatter

      OptionParser.new do |parser|
        parser.on("--packages=PACKAGESLIST", Array, "package names, comma separated") do |p|
          relative_file_paths = p
          ignore_nested_packages = true
        end

        parser.on("--offenses-formatter=FORMATTER", String,
          "identifier of offenses formatter to use") do |formatter_identifier|
          formatter = OffensesFormatter.find(formatter_identifier)
        end

        parser.on("--[no-]parallel", TrueClass, "parallel processing") do |parallel|
          @configuration.parallel = parallel
        end
      end.parse!(args)

      relative_file_paths = args if relative_file_paths.empty?

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
