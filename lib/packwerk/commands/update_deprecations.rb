# typed: true
# frozen_string_literal: true

require "packwerk/commands/offense_printer"
require "packwerk/commands/offense_progress_marker"

module Packwerk
  module Commands
    class UpdateDeprecations
      extend T::Sig
      include OffenseProgressMarker, OffensePrinter

      def initialize(out:, configuration:, files:, progress_formatter:, style:)
        @out = out
        @configuration = configuration
        @files = files
        @progress_formatter = progress_formatter
        @style = style
      end

      sig { returns(T::Boolean) }
      def run
        updating_deprecated_references = UpdatingDeprecatedReferences.new(@configuration.root_path)
        @run_context = RunContext.from_configuration(
          @configuration,
          reference_lister: updating_deprecated_references
        )

        @progress_formatter.started(@files)

        all_offenses = T.let([], T.untyped)
        execution_time = Benchmark.realtime do
          all_offenses = @files.flat_map do |path|
            @run_context.process_file(file: path).tap do |offenses|
              mark_progress(offenses: offenses, progress_formatter: @progress_formatter)
            end
          end

          updating_deprecated_references.dump_deprecated_references_files
        end

        @out.puts # put a new line after the progress dots
        show_offenses(all_offenses, @out, @style)
        @progress_formatter.finished(execution_time)
        @out.puts("✅ `deprecated_references.yml` has been updated.")

        all_offenses.empty?
      end
    end
  end
end
