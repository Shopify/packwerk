# typed: strict
# frozen_string_literal: true

require "optparse"

module Packwerk
  module Commands
    module UsesParseRun
      extend T::Helpers

      requires_ancestor { BaseCommand }

      #: (
      #|   Array[String] args,
      #|   configuration: Configuration,
      #|   out: (StringIO | IO),
      #|   err_out: (StringIO | IO),
      #|   progress_formatter: Formatters::ProgressFormatter,
      #|   offenses_formatter: OffensesFormatter
      #| ) -> void
      def initialize(args, configuration:, out:, err_out:, progress_formatter:, offenses_formatter:)
        super
        @files_for_processing = fetch_files_to_process #: FilesForProcessing
        @offenses_formatter = offenses_formatter_from_options || @offenses_formatter #: OffensesFormatter
        configuration.parallel = parsed_options[:parallel]
      end

      private

      #: -> FilesForProcessing
      def fetch_files_to_process
        FilesForProcessing.fetch(
          relative_file_paths: parsed_options[:relative_file_paths],
          ignore_nested_packages: parsed_options[:ignore_nested_packages],
          configuration: configuration
        )
      end

      #: -> OffensesFormatter?
      def offenses_formatter_from_options
        OffensesFormatter.find(parsed_options[:formatter_name]) if parsed_options[:formatter_name]
      end

      #: -> ParseRun
      def parse_run
        ParseRun.new(
          relative_file_set: @files_for_processing.files,
          parallel: configuration.parallel?,
        )
      end

      #: -> Hash[Symbol, untyped]
      def parsed_options
        return @parsed_options if @parsed_options

        @parsed_options = nil #: Hash[Symbol, untyped]?

        @parsed_options = {
          relative_file_paths: [], #: Array[String]
          ignore_nested_packages: false, #: bool
          formatter_name: nil, #: String?
          parallel: configuration.parallel?,
        }

        OptionParser.new do |parser|
          parser.on("--packages=PACKAGESLIST", Array, "package names, comma separated") do |p|
            @parsed_options[:relative_file_paths] = p
            @parsed_options[:ignore_nested_packages] = true
          end

          parser.on("--offenses-formatter=FORMATTER", String,
            "identifier of offenses formatter to use") do |formatter_name|
            @parsed_options[:formatter_name] = formatter_name
          end

          parser.on("--[no-]parallel", TrueClass, "parallel processing") do |parallel|
            @parsed_options[:parallel] = parallel
          end
        end.parse!(args)

        @parsed_options[:relative_file_paths] = args if @parsed_options[:relative_file_paths].empty?

        @parsed_options
      end
    end

    private_constant :UsesParseRun
  end
end
