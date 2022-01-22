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
        files: T::Array[String],
        configuration: Configuration,
        progress_formatter: Formatters::ProgressFormatter,
        offenses_formatter: OffensesFormatter,
      ).void
    end
    def initialize(
      files:,
      configuration:,
      progress_formatter: Formatters::ProgressFormatter.new(StringIO.new),
      offenses_formatter: Formatters::OffensesFormatter.new
    )
      @configuration = configuration
      @progress_formatter = progress_formatter
      @offenses_formatter = offenses_formatter
      @files = files
    end

    sig { returns(Result) }
    def detect_stale_violations
      offense_collection = find_offenses

      result_status = !offense_collection.stale_violations?
      message = @offenses_formatter.show_stale_violations(offense_collection)

      Result.new(message: message, status: result_status)
    end

    sig { returns(Result) }
    def update_deprecations
      offense_collection = find_offenses
      offense_collection.dump_deprecated_references_files

      message = <<~EOS
        #{@offenses_formatter.show_offenses(offense_collection.errors)}
        ✅ `deprecated_references.yml` has been updated.
      EOS

      Result.new(message: message, status: offense_collection.errors.empty?)
    end

    sig { returns(Result) }
    def check
      offense_collection = find_offenses(show_errors: true)

      messages = [
        @offenses_formatter.show_offenses(offense_collection.outstanding_offenses),
        @offenses_formatter.show_stale_violations(offense_collection),
      ]
      result_status = offense_collection.outstanding_offenses.empty? && !offense_collection.stale_violations?

      Result.new(message: messages.join("\n") + "\n", status: result_status)
    end

    private

    sig { params(show_errors: T::Boolean).returns(OffenseCollection) }
    def find_offenses(show_errors: false)
      offense_collection = OffenseCollection.new(@configuration.root_path)
      @progress_formatter.started(@files)

      run_context = Packwerk::RunContext.from_configuration(@configuration)
      all_offenses = T.let([], T::Array[Offense])

      process_file = T.let(-> (path) do
        run_context.process_file(file: path).tap do |offenses|
          failed = show_errors && offenses.any? { |offense| !offense_collection.listed?(offense) }
          update_progress(failed: failed)
        end
      end, ProcessFileProc)

      execution_time = Benchmark.realtime do
        all_offenses = if @configuration.parallel?
          Parallel.flat_map(@files, &process_file)
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
        @files.each do |path|
          offenses = block.call(path)
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
