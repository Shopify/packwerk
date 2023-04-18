# typed: strict
# frozen_string_literal: true

module Packwerk
  class Cli
    class CheckCommand < BaseCommand
      extend T::Sig
      include UsesParseRun

      register_cli_command "check"

      sig { override.returns(Result) }
      def run
        run_context = RunContext.from_configuration(configuration)
        offense_collection = OffenseCollection.new(configuration.root_path)
        all_offenses = T.let([], T::Array[Offense])
        on_interrupt = T.let(-> { progress_formatter.interrupted }, T.proc.void)

        progress_formatter.started_inspection(files_for_processing.files) do
          all_offenses = parse_run.find_offenses(run_context, on_interrupt: on_interrupt) do |offenses|
            failed = offenses.any? { |offense| !offense_collection.listed?(offense) }
            progress_formatter.increment_progress(failed)
          end
        end
        offense_collection.add_offenses(all_offenses)

        messages = [
          offenses_formatter.show_offenses(offense_collection.outstanding_offenses),
          offenses_formatter.show_stale_violations(offense_collection, files_for_processing.files),
          offenses_formatter.show_strict_mode_violations(offense_collection.strict_mode_violations),
        ]

        result_status = offense_collection.outstanding_offenses.empty? &&
          !offense_collection.stale_violations?(files_for_processing.files) &&
          offense_collection.strict_mode_violations.empty?

        Cli::Result.new(message: messages.select(&:present?).join("\n") + "\n", status: result_status)
      end
    end

    private_constant :CheckCommand
  end
end
