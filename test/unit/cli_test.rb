# typed: true
# frozen_string_literal: true

require "test_helper"
require "rails_test_helper"

module Packwerk
  class CliTest < Minitest::Test
    include TypedMock
    include ApplicationFixtureHelper

    setup do
      setup_application_fixture
      @err_out = StringIO.new
      @cli = ::Packwerk::Cli.new(err_out: @err_out)
    end

    teardown do
      teardown_application_fixture
    end

    test "#execute_command with the subcommand check starts processing files" do
      use_template(:blank)

      file_path = "path/of/exile.rb"
      violation_message = "This is a violation of code health."
      offense = Offense.new(file: file_path, message: violation_message)

      configuration = Configuration.new({ "parallel" => false })
      configuration.stubs(load_paths: {})
      RunContext.any_instance.stubs(:process_file).at_least_once.returns([offense])

      string_io = StringIO.new

      cli = ::Packwerk::Cli.new(out: string_io, configuration: configuration)

      # TODO: Dependency injection for a "target finder" (https://github.com/Shopify/packwerk/issues/164)
      FilesForProcessing.any_instance.stubs(
        files: Set.new([file_path])
      )

      success = cli.execute_command(["check", file_path])

      assert_includes string_io.string, violation_message
      assert_includes string_io.string, "1 offense detected"
      assert_includes string_io.string, "E\n"
      refute success
    end

    test "#execute_command with the subcommand check traps the interrupt signal" do
      use_template(:blank)

      file_path = "path/of/exile.rb"
      interrupt_message = "Manually interrupted. Violations caught so far are listed below:"
      violation_message = "This is a violation of code health."
      offense = Offense.new(file: file_path, message: violation_message)

      configuration = Configuration.new({ "parallel" => false })
      configuration.stubs(load_paths: {})

      RunContext.any_instance.stubs(:process_file)
        .at_least(2)
        .returns([offense])
        .raises(Interrupt)
        .returns([offense])

      string_io = StringIO.new

      cli = ::Packwerk::Cli.new(out: string_io, configuration: configuration)

      FilesForProcessing.any_instance.stubs(
        files: Set.new([file_path, "test.rb", "foo.rb"])
      )

      success = cli.execute_command(["check", file_path])

      assert_includes string_io.string, "Packwerk is inspecting 3 files"
      assert_includes string_io.string, "E\n"
      assert_includes string_io.string, interrupt_message
      assert_includes string_io.string, violation_message
      assert_includes string_io.string, "1 offense detected"
      refute success
    end

    test "#execute_command with the subcommand help lists all the valid subcommands" do
      use_template(:blank)
      @cli.execute_command(["help"])

      assert_match(/Subcommands:/, @err_out.string)
    end

    test "#execute_command with validate subcommand runs application validator and succeeds if no errors" do
      use_template(:blank)

      string_io = StringIO.new
      cli = ::Packwerk::Cli.new(out: string_io)

      validator = typed_mock(check_all: Validator::Result.new(ok: true))
      ApplicationValidator.expects(:new).returns(validator)

      success = cli.execute_command(["validate"])

      assert_includes string_io.string, "Validation successful 🎉\n"
      assert success
    end

    test "#execute_command with validate subcommand runs application validator, fails and prints errors if any" do
      use_template(:blank)
      string_io = StringIO.new
      cli = ::Packwerk::Cli.new(out: string_io)

      validator = typed_mock(check_all: Validator::Result.new(ok: false, error_value: "I'm an error"))
      ApplicationValidator.expects(:new).returns(validator)

      success = cli.execute_command(["validate"])

      assert_includes string_io.string, "Validation failed ❗\n"
      assert_includes string_io.string, "I'm an error"
      refute success
    end

    test "#execute_command with empty subcommand lists all the valid subcommands" do
      use_template(:blank)
      @cli.execute_command([])

      assert_match(/Subcommands:/, @err_out.string)
    end

    test "#execute_command with an invalid subcommand" do
      use_template(:blank)
      @cli.execute_command(["beep boop"])

      expected_output = "'beep boop' is not a packwerk command. See `packwerk help`.\n"
      assert_equal expected_output, @err_out.string
    end

    test "#execute_command using a custom offenses class" do
      use_template(:blank)

      offenses_formatter = Class.new do
        include Packwerk::OffensesFormatter

        def show_offenses(offenses)
          ["hi i am a custom offense formatter", *offenses].join("\n")
        end

        def show_stale_violations(_offense_collection, _fileset)
          "stale violations report"
        end

        def identifier
          "custom"
        end

        def show_strict_mode_violations(_offenses)
          "strict mode violations report"
        end
      end
      file_path = "path/of/exile.rb"
      violation_message = "This is a violation of code health."
      offense = Offense.new(file: file_path, message: violation_message)

      configuration = Configuration.new
      configuration.stubs(load_paths: {})
      RunContext.any_instance.stubs(:process_file)
        .returns([offense])

      string_io = StringIO.new

      cli = ::Packwerk::Cli.new(
        out: string_io,
        configuration: configuration,
        offenses_formatter: T.unsafe(offenses_formatter).new
      )

      FilesForProcessing.any_instance.stubs(
        files: Set.new([file_path])
      )

      success = cli.execute_command(["check", file_path])

      assert_includes string_io.string, "hi i am a custom offense formatter"
      assert_includes string_io.string, "stale violations report"
      assert_includes string_io.string, violation_message

      refute success
    end

    test "#execute_command using a custom offenses class loaded in via packwerk.yml" do
      use_template(:extended)

      file_path = "path/of/exile.rb"
      violation_message = "This is a violation of code health."
      offense = Offense.new(file: file_path, message: violation_message)

      RunContext.any_instance.stubs(:process_file)
        .returns([offense])

      cli = T.let(nil, T.nilable(Packwerk::Cli))
      string_io = StringIO.new
      mock_require_method = ->(required_thing) do
        next unless required_thing.include?("my_local_extension")

        require required_thing
      end

      reset_formatters
      ExtensionLoader.stub(:require, mock_require_method) do
        cli = ::Packwerk::Cli.new(out: string_io)
      end

      FilesForProcessing.any_instance.stubs(
        files: Set.new([file_path])
      )

      success = T.must(cli).execute_command(["check", file_path])

      assert_includes string_io.string, "hi i am a custom offense formatter"
      assert_includes string_io.string, "stale violations report"
      assert_includes string_io.string, violation_message

      refute success

      remove_extensions
    end

    test "#execute_command using a custom offenses class loaded in via flag" do
      use_template(:extended)

      file_path = "path/of/exile.rb"
      violation_message = "This is a violation of code health."
      offense = Offense.new(file: file_path, message: violation_message)

      RunContext.any_instance.stubs(:process_file)
        .returns([offense])

      cli = T.let(nil, T.nilable(Packwerk::Cli))
      string_io = StringIO.new
      mock_require_method = ->(required_thing) do
        next unless required_thing.include?("my_local_extension")

        require required_thing
      end

      reset_formatters
      ExtensionLoader.stub(:require, mock_require_method) do
        cli = ::Packwerk::Cli.new(out: string_io)
      end

      FilesForProcessing.any_instance.stubs(
        files: Set.new([file_path])
      )

      success = T.must(cli).execute_command(["check", "--offenses-formatter=default", file_path])

      assert_includes string_io.string, violation_message
      assert_includes string_io.string, "1 offense detected"
      assert_includes string_io.string, "E\n"

      refute success

      remove_extensions
    end
  end
end
