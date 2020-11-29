# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require "benchmark"

require "packwerk/commands/offense_progress_marker"
require "packwerk/commands/result"
require "packwerk/run_context"
require "packwerk/updating_deprecated_references"

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
        @updating_deprecated_references = T.let(nil, T.nilable(UpdatingDeprecatedReferences))
        @run_context = T.let(nil, T.nilable(RunContext))
      end

      sig { returns(Result) }
      def run
        @progress_formatter.started(@files)

        all_offenses = T.let([], T.untyped)
        execution_time = Benchmark.realtime do
          all_offenses = @files.flat_map do |path|
            run_context.process_file(file: path).tap do |offenses|
              mark_progress(offenses: offenses, progress_formatter: @progress_formatter)
            end
          end

          updating_deprecated_references.dump_deprecated_references_files
        end

        @progress_formatter.finished(execution_time)
        calculate_result(all_offenses)
      end

      private

      sig { returns(RunContext) }
      def run_context
        @run_context ||= RunContext.from_configuration(
          @configuration,
          reference_lister: updating_deprecated_references
        )
      end

      sig { returns(UpdatingDeprecatedReferences) }
      def updating_deprecated_references
        @updating_deprecated_references ||= UpdatingDeprecatedReferences.new(@configuration.root_path)
      end

      sig { params(all_offenses: T::Array[T.nilable(::Packwerk::Offense)]).returns(Result) }
      def calculate_result(all_offenses)
        result_status = all_offenses.empty?
        message = <<~EOS
          #{@offenses_formatter.show_offenses(all_offenses)}
          ✅ `deprecated_references.yml` has been updated.
        EOS

        Result.new(message: message, status: result_status)
      end
    end
  end
end
