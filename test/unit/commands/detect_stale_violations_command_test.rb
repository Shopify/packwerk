# frozen_string_literal: true
require "test_helper"
require "rails_test_helper"
require "packwerk/commands/detect_stale_violations_command"

module Packwerk
  module Commands
    class DetectStaleViolationsCommandTest < Minitest::Test
      test "#run returns status code 1 if stale violations" do
        stale_violations_message = "There were stale violations found, please run `packwerk update-deprecations`"
        offense = Packwerk::Offense.new(file: "path/of/exile.rb", message: stale_violations_message)

        progress_formatter = stub
        progress_formatter.stubs(:started)

        progress_formatter.stubs(:finished)

        run_context = stub
        run_context.stubs(:process_file).returns([offense])

        FilesForProcessing.stubs(fetch: ["path/of/exile.rb"])
        RunContext.stubs(from_configuration: run_context)
        CacheDeprecatedReferences.any_instance.stubs(:stale_violations?).returns(true)

        detect_stale_violations_command = Commands::DetectStaleViolationsCommand.new(
          files: ["path/of/exile.rb"],
          configuration: Configuration.from_path,
          run_context: run_context,
          progress_formatter: progress_formatter
        )

        detect_stale_violations_command.stubs(:mark_progress)

        no_stale_violations = detect_stale_violations_command.run

        assert_equal no_stale_violations.message, stale_violations_message
        refute no_stale_violations.status
      end
    end
  end
end
