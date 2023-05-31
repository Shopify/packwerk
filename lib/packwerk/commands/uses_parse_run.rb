# typed: strict
# frozen_string_literal: true

require "optparse"

module Packwerk
  module Commands
    module UsesParseRun
      extend T::Sig
      extend T::Helpers

      requires_ancestor { BaseCommand }

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
        @_parsed_options = T.let(nil, T.nilable(T::Hash[Symbol, T.untyped]))
        @files_for_processing = T.let(fetch_files_to_process, FilesForProcessing)
        @offenses_formatter = T.let(offenses_formatter_from_options || @offenses_formatter, OffensesFormatter)
        configuration.parallel = parsed_options[:parallel]
      end

      private

      sig { returns(FilesForProcessing) }
      def fetch_files_to_process
        FilesForProcessing.fetch(
          relative_file_paths: parsed_options[:relative_file_paths],
          ignore_nested_packages: parsed_options[:ignore_nested_packages],
          configuration: configuration
        )
      end

      sig { returns(T.nilable(OffensesFormatter)) }
      def offenses_formatter_from_options
        OffensesFormatter.find(parsed_options[:formatter_name]) if parsed_options[:formatter_name]
      end

      sig { returns(ParseRun) }
      def parse_run
        ParseRun.new(
          relative_file_set: @files_for_processing.files,
          parallel: configuration.parallel?,
        )
      end

      sig { returns(T::Hash[Symbol, T.untyped]) }
      def parsed_options
        return @_parsed_options if @_parsed_options

        @_parsed_options = {
          relative_file_paths: T.let([], T::Array[String]),
          ignore_nested_packages: T.let(false, T::Boolean),
          formatter_name: T.let(nil, T.nilable(String)),
          parallel: T.let(configuration.parallel?, T::Boolean),
        }

        OptionParser.new do |parser|
          parser.on("--packages=PACKAGESLIST", Array, "package names, comma separated") do |p|
            @_parsed_options[:relative_file_paths] = p
            @_parsed_options[:ignore_nested_packages] = true
          end

          parser.on("--offenses-formatter=FORMATTER", String,
            "identifier of offenses formatter to use") do |formatter_name|
            @_parsed_options[:formatter_name] = formatter_name
          end

          parser.on("--[no-]parallel", TrueClass, "parallel processing") do |parallel|
            @_parsed_options[:parallel] = parallel
          end
        end.parse!(args)

        @_parsed_options[:relative_file_paths] = args if @_parsed_options[:relative_file_paths].empty?

        @_parsed_options
      end
    end

    private_constant :UsesParseRun
  end
end
