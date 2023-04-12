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

    sig { returns(Configuration) }
    attr_reader :configuration

    sig { returns(OffensesFormatter) }
    attr_reader :offenses_formatter

    sig { returns(Formatters::ProgressFormatter) }
    attr_reader :progress_formatter

    sig { returns(T.any(IO, StringIO)) }
    attr_reader :out

    sig { params(args: T::Array[String]).returns(T.noreturn) }
    def run(args)
      success = execute_command(args)
      exit(success)
    end

    sig { params(args: T::Array[String]).returns(T::Boolean) }
    def execute_command(args)
      subcommand = args.shift || "help"

      result = case subcommand
      when "init"
        InitCommand.new(out: @out, configuration: @configuration).run
      when "check"
        CheckCommand.new(self, args).run
      when "update-todo", "update"
        UpdateCommand.new(parse_run: parse_run(args)).run
      when "validate"
        ValidateCommand.new(
          configuration: @configuration,
          progress_formatter: @progress_formatter,
        ).run
      when "version"
        VersionCommand.new.run
      when "help"
        HelpCommand.new.run
      else
        Result.new(
          status: false,
          message: "'#{subcommand}' is not a packwerk command. See `packwerk help`.",
          print_as_error: true
        )
      end

      if result.print_as_error
        @err_out.puts(result.message)
      else
        @out.puts(result.message)
      end
      result.status
    end

    private

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
