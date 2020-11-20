# typed: false
# frozen_string_literal: true

require "test_helper"
require "rails_test_helper"

module Packwerk
  class CliTest < Minitest::Test
    setup do
      @err_out = StringIO.new
      @cli = ::Packwerk::Cli.new(err_out: @err_out)
    end

    FakeResult = Struct.new(:ok?, :error_value)

    test "#execute_command with the subcommand help lists all the valid subcommands" do
      @cli.execute_command(["help"])

      assert_match(/Subcommands:/, @err_out.string)
    end

    test "#execute_command with validate subcommand runs application validator and succeeds if no errors" do
      string_io = StringIO.new
      cli = ::Packwerk::Cli.new(out: string_io)

      Packwerk::ApplicationValidator.expects(:new).returns(stub(check_all: FakeResult.new(true)))

      success = cli.execute_command(["validate"])

      assert_includes string_io.string, "Validation successful 🎉\n"
      assert success
    end

    test "#execute_command with validate subcommand runs application validator, fails and prints errors if any" do
      string_io = StringIO.new
      cli = ::Packwerk::Cli.new(out: string_io)

      Packwerk::ApplicationValidator.expects(:new).returns(stub(check_all: FakeResult.new(false, "I'm an error")))

      success = cli.execute_command(["validate"])

      assert_includes string_io.string, "Validation failed ❗\n"
      assert_includes string_io.string, "I'm an error"
      refute success
    end

    test "#execute_command with empty subcommand lists all the valid subcommands" do
      @cli.execute_command([])

      assert_match(/Subcommands:/, @err_out.string)
    end

    test "#execute_command with an invalid subcommand" do
      @cli.execute_command(["beep boop"])

      expected_output = "'beep boop' is not a packwerk command. See `packwerk help`.\n"
      assert_equal expected_output, @err_out.string
    end
  end
end
