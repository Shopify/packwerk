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
          dependency_checker: Checker
        ).void
      end
      def initialize(args, configuration:, out:, err_out:, progress_formatter:, offenses_formatter:, dependency_checker:)
        super
        @files_for_processing = T.let(fetch_files_to_process, FilesForProcessing)
        @offenses_formatter = T.let(offenses_formatter_from_options || @offenses_formatter, OffensesFormatter)
        @dependency_checker = T.let(dependency_checker_from_options || @dependency_checker, Checker)
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

      sig { returns(T.nilable(Checker)) }
      def dependency_checker_from_options
        Checker.find(parsed_options[:dependency_checker_name]) if parsed_options[:dependency_checker_name]
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
        return @parsed_options if @parsed_options

        @parsed_options = T.let(nil, T.nilable(T::Hash[Symbol, T.untyped]))

        @parsed_options = {
          relative_file_paths: T.let([], T::Array[String]),
          ignore_nested_packages: T.let(false, T::Boolean),
          formatter_name: T.let(nil, T.nilable(String)),
          dependency_checker_name: T.let(nil, T.nilable(String)),
          parallel: T.let(configuration.parallel?, T::Boolean),
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

          parser.on("--dependency_checker=CHECKER", String,
                    "identifier of dependency checker to use") do |dependency_checker_name|
            @parsed_options[:dependency_checker_name] = dependency_checker_name
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
