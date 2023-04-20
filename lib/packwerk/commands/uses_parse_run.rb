# typed: strict
# frozen_string_literal: true

require "optparse"

module Packwerk
  module Commands
    module UsesParseRun
      extend T::Sig
      extend T::Helpers

      requires_ancestor { Commands::BaseCommand }

      sig do
        params(
          args: T::Array[String],
          configuration: Configuration,
          out: T.any(StringIO, IO),
          err_out: T.any(StringIO, IO),
          progress_formatter: Formatters::ProgressFormatter,
          offenses_formatter: OffensesFormatter,
        ).void
      end
      def initialize(args, configuration:, out:, err_out:, progress_formatter:, offenses_formatter:)
        super
        @parsed_options = T.let(parse_options, T::Hash[Symbol, T.untyped])
        configuration.parallel = @parsed_options[:parallel]
        @files_for_processing = T.let(fetch_files_to_process, FilesForProcessing)
        @offenses_formatter = T.let(find_offenses_formatter || @offenses_formatter, OffensesFormatter)
        configuration.parallel = parsed_options[:parallel]
      end

      private

      sig { returns(T::Hash[Symbol, T.untyped]) }
      attr_reader :parsed_options

      sig { returns(FilesForProcessing) }
      attr_reader :files_for_processing

      sig { returns(FilesForProcessing) }
      def fetch_files_to_process
        FilesForProcessing.fetch(
          relative_file_paths: parsed_options[:relative_file_paths],
          ignore_nested_packages: parsed_options[:ignore_nested_packages],
          configuration: configuration
        )
      end

      sig { returns(T.nilable(OffensesFormatter)) }
      def find_offenses_formatter
        if parsed_options[:formatter_name]
          OffensesFormatter.find(parsed_options[:formatter_name])
        end
      end

      sig { returns(ParseRun) }
      def parse_run
        ParseRun.new(
          relative_file_set: files_for_processing.files,
          parallel: configuration.parallel?,
        )
      end

      sig { returns(T::Hash[Symbol, T.untyped]) }
      def parse_options
        {}.tap do |options|
          options[:relative_file_paths] = T.let([], T::Array[String])
          options[:ignore_nested_packages] = T.let(false, T::Boolean)
          options[:formatter_name] = T.let(nil, T.nilable(String))
          options[:parallel] = T.let(configuration.parallel?, T::Boolean)

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

    private_constant :UsesParseRun
  end
end
