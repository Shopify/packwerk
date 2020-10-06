# typed: true
# frozen_string_literal: true

require "benchmark"

require "packwerk/inflector"
require "packwerk/output_styles"

module Packwerk
  module Formatters
    class ProgressFormatter
      def initialize(out, style: OutputStyles::Plain)
        @out = out
        @style = style
      end

      def started(target_files)
        files_size = target_files.size
        files_string = Inflector.default.pluralize("file", files_size)
        @out.puts("📦 Packwerk is inspecting #{files_size} #{files_string}")
      end

      def started_validation
        @out.puts("📦 Packwerk is running validation...")

        execution_time = Benchmark.realtime { yield }
        finished(execution_time)

        @out.puts("✅ Packages are valid. Use `packwerk check` to run static checks.")
      end

      def mark_as_inspected(_path)
        @out.print(".")
      end

      def mark_as_failed(_path)
        @out.print("#{@style.error}E#{@style.reset}")
      end

      def finished(execution_time)
        @out.puts
        @out.puts("📦 Finished in #{execution_time.round(2)} seconds")
      end
    end
  end
end
