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

    sig { returns(Cli::Result) }
    def update_todo
      if @file_set_specified
        message = <<~MSG.squish
          ⚠️ update-todo must be called without any file arguments.
        MSG

        return Cli::Result.new(message: message, status: false)
      end

      run_context = RunContext.from_configuration(@configuration)
      offenses = T.let([], T::Array[Offense])
      @progress_formatter.started_inspection(@relative_file_set) do
        offenses = find_offenses(run_context, on_interrupt: -> { @progress_formatter.interrupted }) { update_progress }
      end

      offense_collection = OffenseCollection.new(@configuration.root_path)
      offense_collection.add_offenses(offenses)
      offense_collection.persist_package_todo_files(run_context.package_set)

      message = <<~EOS
        #{@offenses_formatter.show_offenses(offense_collection.errors)}
        ✅ `package_todo.yml` has been updated.
      EOS

      Cli::Result.new(message: message, status: offense_collection.errors.empty?)
    end

    sig { returns(Cli::Result) }
    def check
      run_context = RunContext.from_configuration(@configuration)
      offense_collection = OffenseCollection.new(@configuration.root_path)
      offenses = T.let([], T::Array[Offense])

      @progress_formatter.started_inspection(@relative_file_set) do
        offenses = find_offenses(run_context, on_interrupt: -> { @progress_formatter.interrupted }) do |offenses|
          failed = offenses.any? { |offense| !offense_collection.listed?(offense) }
          update_progress(failed: failed)
        end
      end
      offense_collection.add_offenses(offenses)

      messages = [
        @offenses_formatter.show_offenses(offense_collection.outstanding_offenses),
        @offenses_formatter.show_stale_violations(offense_collection, @relative_file_set),
        @offenses_formatter.show_strict_mode_violations(offense_collection.strict_mode_violations),
      ]

      result_status = offense_collection.outstanding_offenses.empty? &&
        !offense_collection.stale_violations?(@relative_file_set) && offense_collection.strict_mode_violations.empty?

      Cli::Result.new(message: messages.select(&:present?).join("\n") + "\n", status: result_status)
    end

    private

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

    sig { params(failed: T::Boolean).void }
    def update_progress(failed: false)
      if failed
        @progress_formatter.mark_as_failed
      else
        @progress_formatter.mark_as_inspected
      end
    end
  end

  private_constant :ParseRun
end
