# typed: false
# frozen_string_literal: true

require "test_helper"
require "rails_test_helper"

module Packwerk
  class CliTest < Minitest::Test
    include TypedMock

    setup do
      @err_out = StringIO.new
      @cli = ::Packwerk::Cli.new(err_out: @err_out)
      @temp_dir = Dir.mktmpdir
    end

    teardown do
      FileUtils.remove_entry(@temp_dir)
    end

    test "#execute_command with the subcommand check starts processing files" do
      file_path = "path/of/exile.rb"
      violation_message = "This is a violation of code health."
      offense = Offense.new(file: file_path, message: violation_message)

      configuration = Configuration.new({ "parallel" => false })
      configuration.stubs(load_paths: {})
      RunContext.any_instance.stubs(:process_file).at_least_once.returns([offense])

      string_io = StringIO.new

      cli = ::Packwerk::Cli.new(out: string_io, configuration: configuration)

      # TODO: Dependency injection for a "target finder" (https://github.com/Shopify/packwerk/issues/164)
      ::Packwerk::FilesForProcessing.stubs(fetch: Set.new([file_path]))

      success = cli.execute_command(["check", file_path])

      assert_includes string_io.string, violation_message
      assert_includes string_io.string, "1 offense detected"
      assert_includes string_io.string, "E\n"
      refute success
    end

    test "#execute_command with the subcommand check traps the interrupt signal" do
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

      ::Packwerk::FilesForProcessing.stubs(fetch: Set.new([file_path, "test.rb", "foo.rb"]))

      success = cli.execute_command(["check", file_path])

      assert_includes string_io.string, "Packwerk is inspecting 3 files"
      assert_includes string_io.string, "E\n"
      assert_includes string_io.string, interrupt_message
      assert_includes string_io.string, violation_message
      assert_includes string_io.string, "1 offense detected"
      refute success
    end

    test "#execute_command with the subcommand help lists all the valid subcommands" do
      @cli.execute_command(["help"])

      assert_match(/Subcommands:/, @err_out.string)
    end

    test "#execute_command with validate subcommand runs application validator and succeeds if no errors" do
      string_io = StringIO.new
      cli = ::Packwerk::Cli.new(out: string_io)

      validator = typed_mock(check_all: ApplicationValidator::Result.new(ok: true))
      Packwerk::ApplicationValidator.expects(:new).returns(validator)

      success = cli.execute_command(["validate"])

      assert_includes string_io.string, "Validation successful 🎉\n"
      assert success
    end

    test "#execute_command with validate subcommand runs application validator, fails and prints errors if any" do
      string_io = StringIO.new
      cli = ::Packwerk::Cli.new(out: string_io)

      validator = typed_mock(check_all: ApplicationValidator::Result.new(ok: false, error_value: "I'm an error"))
      Packwerk::ApplicationValidator.expects(:new).returns(validator)

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

    test "#execute_command using a custom offenses class" do
      offenses_formatter = Class.new do
        include Packwerk::OffensesFormatter

        def show_offenses(offenses)
          ["hi i am a custom offense formatter", *offenses].join("\n")
        end

        def show_stale_violations(_offense_collection, _fileset)
          "stale violations report"
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
        offenses_formatter: offenses_formatter.new
      )

      ::Packwerk::FilesForProcessing.stubs(fetch: Set.new([file_path]))

      success = cli.execute_command(["check", file_path])

      assert_includes string_io.string, "hi i am a custom offense formatter"
      assert_includes string_io.string, "stale violations report"
      assert_includes string_io.string, violation_message

      refute success
    end
  end
end
