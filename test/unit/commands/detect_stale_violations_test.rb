# frozen_string_literal: true
require "test_helper"
require "rails_test_helper"
require "packwerk/commands/detect_stale_violations"

module Packwerk
  module Commands
    class DetectStaleViolationsTest < Minitest::Test
      test "#run returns true if there are no stale violations" do
        offense = Offense.new(file: "path/of/exile.rb", message: "something")
        detect_stale_deprecated_references = stub
        detect_stale_deprecated_references.stubs(:stale_violations?).returns(false)

        run_context = stub
        run_context.stubs(:process_file).returns([offense])

        string_io = StringIO.new
        style = OutputStyles::Plain

        FilesForProcessing.stubs(fetch: ["path/of/exile.rb"])
        RunContext.stubs(from_configuration: run_context)
        DetectStaleDeprecatedReferences.stubs(new: detect_stale_deprecated_references)

        detect_stale_violations_command = Commands::DetectStaleViolations.new(
          out: string_io,
          files: ["path/of/exile.rb"],
          configuration: Configuration.from_path,
          progress_formatter: Formatters::ProgressFormatter.new(string_io, style: style),
        )

        assert detect_stale_violations_command.run
      end

      test "#run returns false if there are stale violations" do
        offense = Offense.new(file: "path/of/exile.rb", message: "something")
        detect_stale_deprecated_references = stub
        detect_stale_deprecated_references.stubs(:stale_violations?).returns(true)

        run_context = stub
        run_context.stubs(:process_file).returns([offense])

        string_io = StringIO.new
        style = OutputStyles::Plain

        FilesForProcessing.stubs(fetch: ["path/of/exile.rb"])
        RunContext.stubs(from_configuration: run_context)
        DetectStaleDeprecatedReferences.stubs(new: detect_stale_deprecated_references)

        detect_stale_violations_command = Commands::DetectStaleViolations.new(
          out: string_io,
          files: ["path/of/exile.rb"],
          configuration: Configuration.from_path,
          progress_formatter: Formatters::ProgressFormatter.new(string_io, style: style),
        )

        refute detect_stale_violations_command.run
      end
    end
  end
end
