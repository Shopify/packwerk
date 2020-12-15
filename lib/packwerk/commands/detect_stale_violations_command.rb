# typed: true
# frozen_string_literal: true
require "sorbet-runtime"
require "benchmark"
require "packwerk/run_context"
require "packwerk/detect_stale_deprecated_references"
require "packwerk/commands/offense_progress_marker"
require "packwerk/commands/result"

module Packwerk
  module Commands
    class DetectStaleViolationsCommand
      extend T::Sig
      include OffenseProgressMarker
      def initialize(files:, configuration:, run_context: nil, progress_formatter: nil, reference_lister: nil)
        @configuration = configuration
        @run_context = run_context
        @reference_lister = reference_lister
        @progress_formatter = progress_formatter
        @files = files
      end

      sig { returns(Result) }
      def run
        @progress_formatter.started(@files)

        execution_time = Benchmark.realtime do
          @files.flat_map do |path|
            run_context.process_file(file: path).tap do |offenses|
              mark_progress(offenses: offenses, progress_formatter: @progress_formatter)
            end
          end
        end

        @progress_formatter.finished(execution_time)
        calculate_result
      end

      private

      def run_context
        @run_context ||= Packwerk::RunContext.from_configuration(@configuration, reference_lister: reference_lister)
      end

      def reference_lister
        @reference_lister ||= ::Packwerk::DetectStaleDeprecatedReferences.new(@configuration.root_path)
      end

      sig { returns(Result) }
      def calculate_result
        result_status = !reference_lister.stale_violations?
        message = "There were stale violations found, please run `packwerk update-deprecations`"
        if result_status
          message = "No stale violations detected"
        end
        Result.new(message: message, status: result_status)
      end
    end
  end
end
