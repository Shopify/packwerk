# typed: strict
# frozen_string_literal: true

require "optparse"

module Packwerk
  class Cli
    module UsesParseRun
      extend T::Sig
      extend T::Helpers

      requires_ancestor { BaseCommand }

      sig { params(cli: Cli, args: T::Array[String]).void }
      def initialize(cli, args)
        super
        @parsed_options = T.let(parse_options, T::Hash[Symbol, T.untyped])
        cli.configuration.parallel = @parsed_options[:parallel]
        @files_for_processing = T.let(fetch_files_to_process, FilesForProcessing)
        @formatter = T.let(find_formatter, OffensesFormatter)
      end

      private

      sig { returns(T::Hash[Symbol, T.untyped]) }
      attr_reader :parsed_options

      sig { returns(FilesForProcessing) }
      attr_reader :files_for_processing

      sig { returns(OffensesFormatter) }
      attr_reader :formatter

      sig { returns(FilesForProcessing) }
      def fetch_files_to_process
        files_for_processing = FilesForProcessing.fetch(
          relative_file_paths: parsed_options[:relative_file_paths],
          ignore_nested_packages: parsed_options[:ignore_nested_packages],
          configuration: cli.configuration
        )
        cli.out.puts(<<~MSG.squish) if files_for_processing.files.empty?
          No files found or given.
          Specify files or check the include and exclude glob in the config file.
        MSG

        files_for_processing
      end

      sig { returns(OffensesFormatter) }
      def find_formatter
        if parsed_options[:formatter_name]
          OffensesFormatter.find(parsed_options[:formatter_name])
        else
          cli.offenses_formatter
        end
      end

      sig { returns(ParseRun) }
      def parse_run
        ParseRun.new(
          relative_file_set: files_for_processing.files,
          file_set_specified: files_for_processing.files_specified?,
          configuration: cli.configuration,
          progress_formatter: cli.progress_formatter,
          offenses_formatter: formatter
        )
      end

      sig { returns(T::Hash[Symbol, T.untyped]) }
      def parse_options
        {}.tap do |options|
          options[:relative_file_paths] = T.let([], T::Array[String])
          options[:ignore_nested_packages] = T.let(false, T::Boolean)
          options[:formatter_name] = T.let(nil, T.nilable(String))
          options[:parallel] = T.let(cli.configuration.parallel?, T::Boolean)

          OptionParser.new do |parser|
            parser.on("--packages=PACKAGESLIST", Array, "package names, comma separated") do |p|
              options[:relative_file_paths] = p
              options[:ignore_nested_packages] = true
            end

            parser.on("--offenses-formatter=FORMATTER", String,
              "identifier of offenses formatter to use") do |formatter_name|
              options[:formatter_name] = formatter_name
            end

            parser.on("--[no-]parallel", TrueClass, "parallel processing") do |parallel|
              options[:parallel] = parallel
            end
          end.parse!(args)

          options[:relative_file_paths] = args if options[:relative_file_paths].empty?
        end
      end
    end
  end
end
