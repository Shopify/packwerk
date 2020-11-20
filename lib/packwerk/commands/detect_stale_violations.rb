# typed: true
# frozen_string_literal: true

require "packwerk/detect_stale_deprecated_references"
require "packwerk/commands/offense_progress_marker"

module Packwerk
  module Commands
    class DetectStaleViolations
      extend T::Sig
      include OffenseProgressMarker
      Result = Struct.new(:message, :status)

      def initialize(out:, files:, configuration:, progress_formatter: nil)
        @out = out
        @files = files
        @configuration = configuration
        @progress_formatter = progress_formatter
      end

      sig { returns(T::Boolean) }
      def run
        @progress_formatter.started(@files)

        all_offenses = T.let([], T.untyped)
        execution_time = Benchmark.realtime do
          all_offenses = @files.flat_map do |path|
            run_context.process_file(file: path).tap do |offenses|
              mark_progress(offenses: offenses, progress_formatter: @progress_formatter)
            end
          end
        end

        @progress_formatter.finished(execution_time)

        @out.puts
        @out.puts(result.message)

        result.status
      end

      private

      def run_context
        @run_context ||= RunContext.from_configuration(@configuration, reference_lister: reference_lister)
      end

      def reference_lister
        @reference_lister ||= DetectStaleDeprecatedReferences.new(@configuration.root_path)
      end

      sig { returns Result }
      def result
        @result ||= begin
          result_status = !reference_lister.stale_violations?
          message = "There were stale violations found, please run `packwerk update`"
          if result_status
            message = "No stale violations detected"
          end
          Result.new(message, result_status)
        end
      end
    end
  end
end
