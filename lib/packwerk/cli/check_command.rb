# typed: strict
# frozen_string_literal: true

module Packwerk
  class Cli
    class CheckCommand
      extend T::Sig

      sig { params(cli: Cli, args: T::Array[String]).void }
      def initialize(cli, args)
        @cli = cli
        @args = args
      end

      sig { returns(Result) }
      def run
        parse_run.check
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
          configuration: @cli.configuration
        )
        @cli.out.puts(<<~MSG.squish) if files_for_processing.files.empty?
          No files found or given.
          Specify files or check the include and exclude glob in the config file.
        MSG

        files_for_processing
      end

      sig { returns(ParseRun) }
      def parse_run
        relative_file_paths = T.let([], T::Array[String])
        ignore_nested_packages = T.let(false, T::Boolean)
        formatter = @cli.offenses_formatter

        OptionParser.new do |parser|
          parser.on("--packages=PACKAGESLIST", Array, "package names, comma separated") do |p|
            relative_file_paths = p
            ignore_nested_packages = true
          end

          parser.on("--offenses-formatter=FORMATTER", String,
            "identifier of offenses formatter to use") do |formatter_identifier|
            formatter = OffensesFormatter.find(formatter_identifier)
          end
        end.parse!(@args)

        relative_file_paths = @args if relative_file_paths.empty?

        files_for_processing = fetch_files_to_process(relative_file_paths, ignore_nested_packages)

        ParseRun.new(
          relative_file_set: files_for_processing.files,
          file_set_specified: files_for_processing.files_specified?,
          configuration: @cli.configuration,
          progress_formatter: @cli.progress_formatter,
          offenses_formatter: formatter
        )
      end
    end

    private_constant :CheckCommand
  end
end
