# frozen_string_literal: true
require "test_helper"
require "rails_test_helper"
require "packwerk/commands/validate"

module Packwerk
  module Commands
    class ValidateTest < Minitest::Test
      FakeResult = Struct.new(:ok?, :error_value)

      test "#execute_command with validate subcommand runs application validator and succeeds if no errors" do
        string_io = StringIO.new
        cli = Cli.new(out: string_io)

        ApplicationValidator.expects(:new).returns(stub(check_all: FakeResult.new(true)))

        success = cli.execute_command(["validate"])

        assert_includes string_io.string, "Validation successful 🎉\n"
        assert success
      end

      test "#execute_command with validate subcommand runs application validator, fails and prints errors if any" do
        string_io = StringIO.new
        cli = Cli.new(out: string_io)

        ApplicationValidator.expects(:new).returns(stub(check_all: FakeResult.new(false, "I'm an error")))

        success = cli.execute_command(["validate"])

        assert_includes string_io.string, "Validation failed ❗\n"
        assert_includes string_io.string, "I'm an error"
        refute success
      end
    end
  end
end
