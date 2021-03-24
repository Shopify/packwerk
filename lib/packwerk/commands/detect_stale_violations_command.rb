# typed: true
# frozen_string_literal: true
require "sorbet-runtime"
require "benchmark"
require "packwerk/run_context"
require "packwerk/commands/offense_progress_marker"
require "packwerk/commands/result"

module Packwerk
  module Commands
    class DetectStaleViolationsCommand
      extend T::Sig
      include OffenseProgressMarker
      def initialize(files:, configuration:, run_context: nil, progress_formatter: nil)
        @configuration = configuration
        @run_context = run_context
        @progress_formatter = progress_formatter
        @files = files
      end

      sig { returns(Result) }
      def run
        @progress_formatter.started(@files)

        all_offenses = T.let([], T.untyped)
        execution_time = Benchmark.realtime do
          all_offenses = Parallel.flat_map(@files) do |path|
            run_context.process_file(file: path).tap do |offenses|
              mark_progress(offenses: offenses, progress_formatter: @progress_formatter)
            end
          end
        end

        deprecated_references = Packwerk::CacheDeprecatedReferences.new(@configuration.root_path)
        all_offenses.each do |offense|
          next unless offense.is_a?(ReferenceOffense)
          deprecated_references.add_offense(offense)
        end

        @progress_formatter.finished(execution_time)
        calculate_result(deprecated_references)
      end

      private

      def run_context
        @run_context ||= Packwerk::RunContext.from_configuration(@configuration)
      end

      sig { params(deprecated_references: Packwerk::CacheDeprecatedReferences).returns(Result) }
      def calculate_result(deprecated_references)
        result_status = !deprecated_references.stale_violations?
        message = "There were stale violations found, please run `packwerk update-deprecations`"
        if result_status
          message = "No stale violations detected"
        end
        Result.new(message: message, status: result_status)
      end
    end
  end
end
