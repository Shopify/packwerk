# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require "benchmark"

require "packwerk/cache_deprecated_references"
require "packwerk/commands/offense_progress_marker"
require "packwerk/commands/result"
require "packwerk/reference_offense"
require "packwerk/run_context"
require "parallel"

module Packwerk
  module Commands
    class UpdateDeprecationsCommand
      extend T::Sig
      include OffenseProgressMarker

      sig do
        params(
          files: T::Enumerable[String],
          configuration: Configuration,
          offenses_formatter: Formatters::OffensesFormatter,
          progress_formatter: Formatters::ProgressFormatter
        ).void
      end
      def initialize(files:, configuration:, offenses_formatter:, progress_formatter:)
        @files = files
        @configuration = configuration
        @progress_formatter = progress_formatter
        @offenses_formatter = offenses_formatter
        @run_context = T.let(nil, T.nilable(RunContext))
      end

      sig { returns(Result) }
      def run
        @progress_formatter.started(@files)

        deprecated_references = CacheDeprecatedReferences.new(@configuration.root_path)
        new_offenses = false

        execution_time = Benchmark.realtime do
          all_offenses = Parallel.flat_map(@files) do |path|
            run_context.process_file(file: path).tap do |offenses|
              mark_progress(offenses: [], progress_formatter: @progress_formatter)
              offenses
            end
          end

          all_offenses.each do |offense|
            next unless offense.is_a?(ReferenceOffense)
            deprecated_references.add_offense(offense)
          end

          new_offenses = deprecated_references.new_offenses?

          deprecated_references.dump_deprecated_references_files
        end

        @progress_formatter.finished(execution_time)
        calculate_result(new_offenses)
      end

      private

      sig { returns(RunContext) }
      def run_context
        @run_context ||= RunContext.from_configuration(@configuration)
      end

      sig { params(new_offenses: T::Boolean).returns(Result) }
      def calculate_result(new_offenses)
        result_status = !new_offenses
        message = "✅ `deprecated_references.yml` has been updated."

        Result.new(message: message, status: result_status)
      end
    end
  end
end
