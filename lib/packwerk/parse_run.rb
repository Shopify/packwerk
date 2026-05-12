# typed: strict
# frozen_string_literal: true

module Packwerk
  class ParseRun
    #: (relative_file_set: FilesForProcessing::relative_file_set, ?all_files: FilesForProcessing::relative_file_set, ?parallel: bool) -> void
    def initialize(relative_file_set:, all_files: relative_file_set, parallel: true)
      @relative_file_set = relative_file_set
      @all_files = all_files
      # NOTE: parallel flag accepted for interface compatibility but ignored.
      # Rubydex handles heavy lifting in Rust; the remaining Ruby work is too lightweight
      # for fork-based parallelism to help.
      _ = parallel
    end

    #: (RunContext run_context, ?on_interrupt: (^-> void)?) ?{ (Array[Packwerk::Offense] offenses) -> void } -> Array[Offense]
    def find_offenses(run_context, on_interrupt: nil, &block)
      # Phase 1: Index all workspace files and resolve constants via Rubydex
      run_context.index_and_resolve(@relative_file_set, all_files: @all_files)

      # Phase 2: Walk resolved references, check violations, report per-file
      run_context.find_offenses(@relative_file_set, &block)
    rescue Interrupt
      on_interrupt&.call
      []
    end
  end

  private_constant :ParseRun
end
