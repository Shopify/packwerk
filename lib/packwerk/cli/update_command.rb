# typed: strict
# frozen_string_literal: true

module Packwerk
  class Cli
    class UpdateCommand < BaseCommand
      extend T::Sig
      include UsesParseRun

      register_cli_command "update", "update-todo"

      sig { override.returns(Result) }
      def run
        if files_for_processing.files_specified?
          message = <<~MSG.squish
            ⚠️ update-todo must be called without any file arguments.
          MSG

          return Cli::Result.new(message: message, status: false)
        end

        run_context = RunContext.from_configuration(configuration)
        offenses = T.let([], T::Array[Offense])
        progress_formatter.started_inspection(files_for_processing.files) do
          offenses = parse_run.find_offenses(run_context, on_interrupt: -> { progress_formatter.interrupted }) do
            progress_formatter.increment_progress
          end
        end

        offense_collection = OffenseCollection.new(configuration.root_path)
        offense_collection.add_offenses(offenses)
        offense_collection.persist_package_todo_files(run_context.package_set)

        message = <<~EOS
          #{offenses_formatter.show_offenses(offense_collection.errors)}
          ✅ `package_todo.yml` has been updated.
        EOS

        Cli::Result.new(message: message, status: offense_collection.errors.empty?)
      end
    end

    private_constant :UpdateCommand
  end
end
