# typed: strict
# frozen_string_literal: true

module Packwerk
  module Commands
    class CheckCommand < BaseCommand
      extend T::Sig
      include UsesParseRun

      description "run all checks"

      # @override
      #: -> bool
      def run
        if @files_for_processing.files.empty?
          out.puts(<<~MSG.squish)
            No files found or given.
            Specify files or check the include and exclude glob in the config file.
          MSG

          true
        end

        all_offenses = [] #: Array[Offense]
        on_interrupt = -> { progress_formatter.interrupted } #: ^-> void

        progress_formatter.started_inspection(@files_for_processing.files) do
          all_offenses = parse_run.find_offenses(run_context, on_interrupt: on_interrupt) do |offenses|
            failed = offenses.any? { |offense| !offense_collection.listed?(offense) }
            progress_formatter.increment_progress(failed)
          end
        end
        offense_collection.add_offenses(all_offenses)

        unlisted_strict_mode_violations = offense_collection.unlisted_strict_mode_violations

        messages = [
          offenses_formatter.show_offenses(offense_collection.outstanding_offenses),
          offenses_formatter.show_stale_violations(offense_collection, @files_for_processing.files),
          offenses_formatter.show_strict_mode_violations(unlisted_strict_mode_violations),
        ]

        out.puts(messages.select(&:present?).join("\n") + "\n")

        offense_collection.outstanding_offenses.empty? &&
          !offense_collection.stale_violations?(@files_for_processing.files) &&
          unlisted_strict_mode_violations.empty?
      end

      private

      #: -> RunContext
      def run_context
        @run_context ||= RunContext.from_configuration(configuration) #: RunContext?
      end

      #: -> OffenseCollection
      def offense_collection
        @offense_collection ||= OffenseCollection.new(configuration.root_path) #: OffenseCollection?
      end
    end
  end
end
