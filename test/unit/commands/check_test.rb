# frozen_string_literal: true
require "test_helper"
require "rails_test_helper"
require "packwerk/commands/check"

module Packwerk
  module Commands
    class CheckTest < Minitest::Test
      test "#run prints no violations and return true" do
        run_context = stub
        run_context.stubs(:process_file).at_least_once.returns([])

        string_io = StringIO.new
        style = OutputStyles::Plain

        # TODO: Dependency injection for a "target finder" (https://github.com/Shopify/packwerk/issues/164)
        FilesForProcessing.stubs(fetch: ["path/of/exile.rb"])

        check_command = Commands::Check.new(
          out: string_io,
          files: ["path/of/exile.rb"],
          run_context: run_context,
          progress_formatter: Formatters::ProgressFormatter.new(string_io, style: style),
          style: style
        )

        assert check_command.run
        assert_includes string_io.string, "No offenses detected"
      end

      test "#run prints violations and return false" do
        violation_message = "This is a violation of code health."
        offense = stub(error?: true, to_s: violation_message)

        run_context = stub
        run_context.stubs(:process_file).at_least_once.returns([offense])

        string_io = StringIO.new
        style = OutputStyles::Plain

        # TODO: Dependency injection for a "target finder" (https://github.com/Shopify/packwerk/issues/164)
        FilesForProcessing.stubs(fetch: ["path/of/exile.rb"])

        check_command = Commands::Check.new(
          out: string_io,
          files: ["path/of/exile.rb"],
          run_context: run_context,
          progress_formatter: Formatters::ProgressFormatter.new(string_io, style: style),
          style: style
        )

        refute check_command.run
        assert_includes string_io.string, violation_message
        assert_includes string_io.string, "1 offense detected"
        assert_includes string_io.string, "E\n"
      end
    end
  end
end
