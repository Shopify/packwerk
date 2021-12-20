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
      all_results = T.let([], T::Array[RunContext::ProcessedFileResult])

      process_file = -> (path) do
        run_context.process_file(file: path).tap do |results|
          failed = show_errors && results.offenses.any? { |offense| !offense_collection.listed?(offense) }
          update_progress(failed: failed)
        end
      end

      execution_time = Benchmark.realtime do
        all_results = Cache.with_cache(@files, parallel: @configuration.parallel?, root_path: @configuration.root_path) do |uncached_files|
          if @configuration.parallel?
            Parallel.flat_map(uncached_files, &process_file)
          else
            serial_find_results(uncached_files, &process_file)
          end
        end
      end

      @progress_formatter.finished(execution_time)

      all_results.flat_map(&:offenses).each { |offense| offense_collection.add_offense(offense) }
      offense_collection
    end

    def serial_find_results(files)
      all_results = T.let([], T::Array[RunContext::ProcessedFileResult])
      files.each do |path|
        result = yield path
        all_results << result
      end
      all_results
    rescue Interrupt
      @progress_formatter.interrupted
      all_results
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
