# frozen_string_literal: true
require "test_helper"
require "rails_test_helper"
require "packwerk/commands/validate"

module Packwerk
  module Commands
    class ValidateTest < Minitest::Test
      FakeResult = Struct.new(:ok?, :error_value)

      test "#run runs application validator and succeeds if no errors" do
        string_io = StringIO.new
        style = OutputStyles::Plain

        ApplicationValidator.expects(:new).returns(stub(check_all: FakeResult.new(true)))

        validate_command = Commands::Validate.new(
          out: string_io,
          configuration: Configuration.from_path,
          progress_formatter: Formatters::ProgressFormatter.new(string_io, style: style),
        )

        assert validate_command.run
        assert_includes string_io.string, "Validation successful 🎉\n"
      end

      test "#run runs application validator, fails and prints errors if any" do
        string_io = StringIO.new
        style = OutputStyles::Plain

        ApplicationValidator.expects(:new).returns(stub(check_all: FakeResult.new(false, "I'm an error")))

        validate_command = Commands::Validate.new(
          out: string_io,
          configuration: Configuration.from_path,
          progress_formatter: Formatters::ProgressFormatter.new(string_io, style: style),
        )

        refute validate_command.run
        assert_includes string_io.string, "Validation failed ❗\n"
        assert_includes string_io.string, "I'm an error"
      end
    end
  end
end
