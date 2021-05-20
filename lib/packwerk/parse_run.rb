# typed: true
# frozen_string_literal: true
require "sorbet-runtime"
require "benchmark"
require "packwerk/run_context"
require "packwerk/detect_stale_deprecated_references"
require "packwerk/commands/offense_progress_marker"
require "packwerk/result"

module Packwerk
  class ParseRun
    extend T::Sig
    include OffenseProgressMarker

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
      reference_lister = DetectStaleDeprecatedReferences.new(@configuration.root_path)
      run(reference_lister)
      result_status = !reference_lister.stale_violations?

      message = if result_status
        "No stale violations detected"
      else
        "There were stale violations found, please run `packwerk update-deprecations`"
      end

      Result.new(message: message, status: result_status)
    end

    def update_deprecations
      reference_lister = UpdatingDeprecatedReferences.new(@configuration.root_path)
      offenses = run(reference_lister)
      reference_lister.dump_deprecated_references_files

      message = <<~EOS
        #{@offenses_formatter.show_offenses(offenses)}
        ✅ `deprecated_references.yml` has been updated.
      EOS

      Result.new(message: message, status: offenses.empty?)
    end

    def check
      reference_lister = CheckingDeprecatedReferences.new(@configuration.root_path)
      offenses = run(reference_lister)

      message = @offenses_formatter.show_offenses(offenses)
      Result.new(message: message, status: offenses.empty?)
    end

    private

    def run(reference_lister)
      @progress_formatter.started(@files)

      run_context = Packwerk::RunContext.from_configuration(@configuration, reference_lister: reference_lister)
      all_offenses = T.let([], T.untyped)
      execution_time = Benchmark.realtime do
        @files.each do |path|
          run_context.process_file(file: path).tap do |offenses|
            mark_progress(offenses: offenses, progress_formatter: @progress_formatter)
            all_offenses.concat(offenses)
          end
        end
      rescue Interrupt
        @progress_formatter.interrupted
      end

      @progress_formatter.finished(execution_time)
      all_offenses
    end
  end
end
