# typed: strict
# frozen_string_literal: true

require "benchmark"
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
        full_codebase_run: T::Boolean,
        offenses_formatter: T.nilable(OffensesFormatter),
        progress_formatter: Formatters::ProgressFormatter,
      ).void
    end
    def initialize(
      relative_file_set:,
      configuration:,
      full_codebase_run: false,
      offenses_formatter: nil,
      progress_formatter: Formatters::ProgressFormatter.new(StringIO.new)
    )

      @configuration = configuration
      @progress_formatter = progress_formatter
      @offenses_formatter = T.let(offenses_formatter || configuration.offenses_formatter, Packwerk::OffensesFormatter)
      @relative_file_set = relative_file_set
      @full_codebase_run = full_codebase_run
    end

    sig { returns(Result) }
    def update_todo
      run_context = Packwerk::RunContext.from_configuration(@configuration)
      offense_collection = find_offenses(run_context)
      offense_collection.persist_package_todo_files(run_context.package_set, full_codebase_run: @full_codebase_run)

      message = <<~EOS
        #{@offenses_formatter.show_offenses(offense_collection.errors)}
        ✅ `package_todo.yml` has been updated.
      EOS

      Result.new(message: message, status: offense_collection.errors.empty?)
    end

    sig { returns(Result) }
    def check
      run_context = Packwerk::RunContext.from_configuration(@configuration)
      offense_collection = find_offenses(run_context, show_errors: true)

      messages = [
        @offenses_formatter.show_offenses(offense_collection.outstanding_offenses),
        @offenses_formatter.show_stale_violations(offense_collection, @relative_file_set),
      ]

      result_status = offense_collection.outstanding_offenses.empty? &&
        !offense_collection.stale_violations?(@relative_file_set)

      Result.new(message: messages.join("\n") + "\n", status: result_status)
    end

    private

    sig { params(run_context: Packwerk::RunContext, show_errors: T::Boolean).returns(OffenseCollection) }
    def find_offenses(run_context, show_errors: false)
      offense_collection = OffenseCollection.new(@configuration.root_path)
      @progress_formatter.started(@relative_file_set)

      all_offenses = T.let([], T::Array[Offense])

      process_file = T.let(->(relative_file) do
        run_context.process_file(relative_file: relative_file).tap do |offenses|
          failed = show_errors && offenses.any? { |offense| !offense_collection.listed?(offense) }
          update_progress(failed: failed)
        end
      end, ProcessFileProc)

      execution_time = Benchmark.realtime do
        all_offenses = if @configuration.parallel?
          Parallel.flat_map(@relative_file_set, &process_file)
        else
          serial_find_offenses(&process_file)
        end
      end

      @progress_formatter.finished(execution_time)

      all_offenses.each { |offense| offense_collection.add_offense(offense) }
      offense_collection
    end

    sig { params(block: ProcessFileProc).returns(T::Array[Offense]) }
    def serial_find_offenses(&block)
      all_offenses = T.let([], T::Array[Offense])
      begin
        @relative_file_set.each do |relative_file|
          offenses = yield(relative_file)
          all_offenses.concat(offenses)
        end
      rescue Interrupt
        @progress_formatter.interrupted
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
end
