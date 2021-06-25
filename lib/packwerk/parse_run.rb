# typed: true
# frozen_string_literal: true

require "benchmark"
require "parallel"

module Packwerk
  class ParseRun
    extend T::Sig

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

    def detect_stale_violations
      offense_collection = find_offenses

      result_status = !offense_collection.stale_violations?
      message = @offenses_formatter.show_stale_violations(offense_collection)

      Result.new(message: message, status: result_status)
    end

    def update_deprecations
      offense_collection = find_offenses
      offense_collection.dump_deprecated_references_files

      message = <<~EOS
        #{@offenses_formatter.show_offenses(offense_collection.errors)}
        ✅ `deprecated_references.yml` has been updated.
      EOS

      Result.new(message: message, status: offense_collection.errors.empty?)
    end

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

    def find_offenses(show_errors: false)
      offense_collection = OffenseCollection.new(@configuration.root_path)
      @progress_formatter.started(@files)

      run_context = Packwerk::RunContext.from_configuration(@configuration)
      all_offenses = T.let([], T.untyped)

      process_file = -> (path) do
        run_context.process_file(file: path).tap do |offenses|
          failed = show_errors && offenses.any? { |offense| !offense_collection.listed?(offense) }
          update_progress(failed: failed)
        end
      end

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

    def serial_find_offenses
      all_offenses = T.let([], T.untyped)
      @files.each do |path|
        offenses = yield path
        all_offenses.concat(offenses)
      end
      all_offenses
    rescue Interrupt
      @progress_formatter.interrupted
      all_offenses
    end

    def update_progress(failed: false)
      if failed
        @progress_formatter.mark_as_failed
      else
        @progress_formatter.mark_as_inspected
      end
    end
  end
end
