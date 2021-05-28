# typed: true
# frozen_string_literal: true

require "benchmark"

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
      reference_lister = DetectStaleDeprecatedReferences.new(@configuration.root_path)
      find_offenses.each do |offense|
        next unless offense.is_a?(ReferenceOffense)
        reference_lister.listed?(offense.reference, violation_type: offense.violation_type)
      end

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
      offenses = find_offenses(show_errors: false)

      offenses = offenses.select do |offense|
        next true unless offense.is_a?(ReferenceOffense)
        reference_lister.listed?(offense.reference, violation_type: offense.violation_type)
        false
      end

      reference_lister.dump_deprecated_references_files

      message = <<~EOS
        #{@offenses_formatter.show_offenses(offenses)}
        ✅ `deprecated_references.yml` has been updated.
      EOS

      Result.new(message: message, status: offenses.empty?)
    end

    def check
      reference_lister = CheckingDeprecatedReferences.new(@configuration.root_path)
      new_offenses = find_offenses.reject do |offense|
        next false unless offense.is_a?(ReferenceOffense)
        reference_lister.listed?(offense.reference, violation_type: offense.violation_type)
      end
      message = @offenses_formatter.show_offenses(new_offenses)
      Result.new(message: message, status: new_offenses.empty?)
    end

    private

    def find_offenses(show_errors: true)
      @progress_formatter.started(@files)

      run_context = Packwerk::RunContext.from_configuration(@configuration)
      all_offenses = T.let([], T.untyped)
      execution_time = Benchmark.realtime do
        @files.each do |path|
          run_context.process_file(file: path).tap do |offenses|
            if offenses.any? && show_errors
              @progress_formatter.mark_as_failed
            else
              @progress_formatter.mark_as_inspected
            end
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
