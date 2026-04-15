# typed: strict
# frozen_string_literal: true

require "parallel"

module Packwerk
  class ParseRun
    extend T::Sig

    sig do
      params(
        relative_file_set: FilesForProcessing::RelativeFileSet,
        parallel: T::Boolean,
      ).void
    end
    def initialize(relative_file_set:, parallel: true)
      @relative_file_set = relative_file_set
      @parallel = parallel
    end

    sig do
      params(
        run_context: RunContext,
        on_interrupt: T.nilable(T.proc.void),
        block: T.nilable(T.proc.params(
          offenses: T::Array[Packwerk::Offense],
        ).void)
      ).returns(T::Array[Offense])
    end
    def find_offenses(run_context, on_interrupt: nil, &block)
      # Phase 1: Index all files and resolve constants via Rubydex
      run_context.index_and_resolve(@relative_file_set)

      # Phase 2: Walk resolved references, check violations, report per-file
      run_context.find_offenses(@relative_file_set, &block)
    rescue Interrupt
      on_interrupt&.call
      []
    end
  end

  private_constant :ParseRun
end
