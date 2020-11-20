# typed: true
# frozen_string_literal: true

require "packwerk/commands/offense_printer"
require "packwerk/commands/offense_progress_marker"

module Packwerk
  module Commands
    class Check
      extend T::Sig
      include OffenseProgressMarker, OffensePrinter

      def initialize(out:, files:, run_context:, progress_formatter:, style:)
        @out = out
        @files = files
        @run_context = run_context
        @progress_formatter = progress_formatter
        @style = style
      end

      sig { returns(T::Boolean) }
      def run
        @progress_formatter.started(@files)

        all_offenses = T.let([], T.untyped)
        execution_time = Benchmark.realtime do
          @files.each do |path|
            @run_context.process_file(file: path).tap do |offenses|
              mark_progress(offenses: offenses, progress_formatter: @progress_formatter)
              all_offenses.concat(offenses)
            end
          end
        rescue Interrupt
          @out.puts
          @out.puts("Manually interrupted. Violations caught so far are listed below:")
        end

        @out.puts # put a new line after the progress dots
        show_offenses(all_offenses, @out, @style)
        @progress_formatter.finished(execution_time)

        all_offenses.empty?
      end
    end
  end
end
