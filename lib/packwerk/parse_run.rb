# typed: strict
# frozen_string_literal: true

require "parallel"

module Packwerk
  class ParseRun
    extend T::Sig

    ProcessFileProc = T.type_alias do
      T.proc.params(path: String).returns(T::Array[Offense])
    end

    sig do
      params(
        relative_file_set: FilesForProcessing::RelativeFileSet,
        configuration: Configuration,
        file_set_specified: T::Boolean,
        offenses_formatter: T.nilable(OffensesFormatter),
        progress_formatter: Formatters::ProgressFormatter,
      ).void
    end
    def initialize(
      relative_file_set:,
      configuration:,
      file_set_specified: false,
      offenses_formatter: nil,
      progress_formatter: Formatters::ProgressFormatter.new(StringIO.new)
    )

      @configuration = configuration
      @progress_formatter = progress_formatter
      @offenses_formatter = T.let(offenses_formatter || configuration.offenses_formatter, Packwerk::OffensesFormatter)
      @relative_file_set = relative_file_set
      @file_set_specified = file_set_specified
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
      process_file_proc = process_file_proc(run_context, &block)

      offenses = if @configuration.parallel?
        Parallel.flat_map(@relative_file_set, &process_file_proc)
      else
        serial_find_offenses(on_interrupt: on_interrupt, &process_file_proc)
      end

      offenses
    end

    private

    sig do
      params(
        run_context: RunContext,
        block: T.nilable(T.proc.params(offenses: T::Array[Offense]).void)
      ).returns(ProcessFileProc)
    end
    def process_file_proc(run_context, &block)
      if block
        T.let(proc do |relative_file|
          run_context.process_file(relative_file: relative_file).tap(&block)
        end, ProcessFileProc)
      else
        T.let(proc do |relative_file|
          run_context.process_file(relative_file: relative_file)
        end, ProcessFileProc)
      end
    end

    sig do
      params(
        on_interrupt: T.nilable(T.proc.void),
        block: ProcessFileProc
      ).returns(T::Array[Offense])
    end
    def serial_find_offenses(on_interrupt: nil, &block)
      all_offenses = T.let([], T::Array[Offense])
      begin
        @relative_file_set.each do |relative_file|
          offenses = yield(relative_file)
          all_offenses.concat(offenses)
        end
      rescue Interrupt
        on_interrupt&.call
        all_offenses
      end
      all_offenses
    end
  end

  private_constant :ParseRun
end
