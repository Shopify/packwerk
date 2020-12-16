# typed: false
# frozen_string_literal: true

require "test_helper"
require "rails_test_helper"

module Packwerk
  class CliTest < Minitest::Test
    setup do
      @err_out = StringIO.new
      @cli = ::Packwerk::Cli.new(err_out: @err_out)
      @temp_dir = Dir.mktmpdir
    end

    teardown do
      FileUtils.remove_entry(@temp_dir)
    end

    FakeResult = Struct.new(:ok?, :error_value)

    class FakeOffense < Packwerk::Offense
      def initialize; end
    end

    class FakeRunContext < Packwerk::RunContext
      def initialize; end
    end

    class FakeConfiguration < Packwerk::Configuration
      def initialize; end
    end

    test "#execute_command with the subcommand check starts processing files" do
      violation_message = "This is a violation of code health."
      offense = FakeOffense.new
      offense.stubs(:to_s).returns(violation_message)

      run_context = FakeRunContext.new
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
      offense = FakeOffense.new
      offense.stubs(:to_s).returns(violation_message)

      run_context = FakeRunContext.new
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

    test "#execute_command with init subcommand runs application validation generator for non-Rails app" do
      string_io = StringIO.new
      configuration = FakeConfiguration.new
      configuration.stubs(
        root_path: @temp_dir,
        load_paths: ["path"],
        package_paths: "**/",
        custom_associations: ["cached_belongs_to"],
        inflections_file: "config/inflections.yml"
      )
      cli = ::Packwerk::Cli.new(configuration: configuration, out: string_io)

      Packwerk::Generators::ApplicationValidation.expects(:generate).returns(true)
      success = cli.execute_command(["init"])

      assert_includes string_io.string, "is ready to be used"
      assert success
    end

    test "#execute_command with init subcommand runs application validation generator, fails and prints error" do
      string_io = StringIO.new
      configuration = FakeConfiguration.new
      configuration.stubs(
        root_path: @temp_dir,
        load_paths: ["path"],
        package_paths: "**/",
        custom_associations: ["cached_belongs_to"],
        inflections_file: "config/inflections.yml"
      )
      cli = ::Packwerk::Cli.new(configuration: configuration, out: string_io)

      Packwerk::Generators::ApplicationValidation.expects(:generate).returns(false)
      success = cli.execute_command(["init"])

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
