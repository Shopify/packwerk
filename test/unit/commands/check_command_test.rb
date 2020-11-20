# frozen_string_literal: true
require "test_helper"
require "rails_test_helper"
require "packwerk/commands/check_command"

module Packwerk
  class CheckCommandTest < Minitest::Test
    test "#execute_command with the subcommand check starts processing files" do
      violation_message = "This is a violation of code health."
      offense = stub(error?: true, to_s: violation_message)

      run_context = stub
      run_context.stubs(:process_file).at_least_once.returns([offense])

      string_io = StringIO.new

      cli = ::Packwerk::Cli.new(out: string_io, run_context: run_context)

      # TODO: Dependency injection for a "target finder" (https://github.com/Shopify/packwerk/issues/164)
      ::Packwerk::FilesForProcessing.stubs(fetch: ["path/of/exile.rb"])

      success = cli.execute_command(["check", "path/of/exile.rb"])

      assert_includes string_io.string, violation_message
      assert_includes string_io.string, "1 offense detected"
      assert_includes string_io.string, "E\n"
      refute success
    end

    test "#execute_command with the subcommand check traps the interrupt signal" do
      interrupt_message = "Manually interrupted. Violations caught so far are listed below:"
      violation_message = "This is a violation of code health."
      offense = stub(to_s: violation_message)

      run_context = stub
      run_context.stubs(:process_file)
        .at_least(2)
        .returns([offense])
        .raises(Interrupt)
        .returns([offense])

      string_io = StringIO.new

      cli = ::Packwerk::Cli.new(out: string_io, run_context: run_context)

      ::Packwerk::FilesForProcessing.stubs(fetch: ["path/of/exile.rb", "test.rb", "foo.rb"])

      success = cli.execute_command(["check", "path/of/exile.rb"])

      assert_includes string_io.string, "Packwerk is inspecting 3 files"
      assert_includes string_io.string, "E\n"
      assert_includes string_io.string, interrupt_message
      assert_includes string_io.string, violation_message
      assert_includes string_io.string, "1 offense detected"
      refute success
    end
  end
end
