# typed: strict
# frozen_string_literal: true

require "benchmark"

module Packwerk
  module Formatters
    class ProgressFormatter
      #: ((StringIO | IO) out, ?style: OutputStyle) -> void
      def initialize(out, style: OutputStyles::Plain.new)
        @out = out
        @style = style
      end

      #: { -> void } -> void
      def started_validation(&block)
        start_validation

        execution_time = Benchmark.realtime(&block)
        finished(execution_time)
      end

      #: (FilesForProcessing::relative_file_set target_files) { -> void } -> void
      def started_inspection(target_files, &block)
        start_inspection(target_files)

        execution_time = Benchmark.realtime(&block)
        finished(execution_time)
      end

      #: (?bool failed) -> void
      def increment_progress(failed = false)
        if failed
          mark_as_failed
        else
          mark_as_inspected
        end
      end

      #: -> void
      def mark_as_inspected
        @out.print(".")
      end

      #: -> void
      def mark_as_failed
        @out.print("#{@style.error}E#{@style.reset}")
      end

      #: -> void
      def interrupted
        @out.puts
        @out.puts("Manually interrupted. Violations caught so far are listed below:")
        @out.puts
      end

      private

      #: (Float execution_time) -> void
      def finished(execution_time)
        @out.puts
        @out.puts("📦 Finished in #{execution_time.round(2)} seconds")
        @out.puts
      end

      #: -> void
      def start_validation
        @out.puts("📦 Packwerk is running validation...")
      end

      #: (FilesForProcessing::relative_file_set target_files) -> void
      def start_inspection(target_files)
        files_size = target_files.size
        files_string = "file".pluralize(files_size)
        @out.puts("📦 Packwerk is inspecting #{files_size} #{files_string}")
      end
    end
  end
end
