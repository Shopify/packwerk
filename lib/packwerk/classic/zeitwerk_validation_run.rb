# typed: false
# frozen_string_literal: true

require "benchmark"
require "parallel"

module Packwerk
  module Classic
    class ZeitwerkValidationRun
      def initialize(
        configuration:,
        progress_formatter: Formatters::ProgressFormatter.new(StringIO.new),
        offenses_formatter: Formatters::OffensesFormatter.new
      )
        @configuration = configuration
        @progress_formatter = progress_formatter
        @offenses_formatter = offenses_formatter
        @files = autoloadable_file_paths
      end

      def detect_zeitwerk_violations
        offense_collection = find_offenses(show_errors: true)
        message = @offenses_formatter.show_offenses(offense_collection.outstanding_offenses)
        Result.new(message: message, status: offense_collection.outstanding_offenses.empty?)
      end

      def find_offenses(show_errors: false)
        offense_collection = OffenseCollection.new(@configuration.root_path)
        @progress_formatter.started(@files)

        resolver = Packwerk::Classic::ResolveConstantDefinitions.new(configuration: @configuration)
        all_offenses = T.let([], T.untyped)

        process_file = -> (path) do
          resolver.collect_file_offenses(path).tap do |offenses|
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

      private

      def autoloadable_file_paths
        root_path = Pathname.new(@configuration.root_path)
        @configuration.load_paths.map do |load_path|
          Dir.glob(File.join(root_path, load_path, "**", "*.rb"))
        end.flatten
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
end
