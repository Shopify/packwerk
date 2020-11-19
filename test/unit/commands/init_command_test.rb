# frozen_string_literal: true
require "test_helper"
require "rails_test_helper"
require "packwerk/commands/init_command"

module Packwerk
  class InitCommandTest < Minitest::Test
    setup do
      @temp_dir = Dir.mktmpdir
    end

    teardown do
      FileUtils.remove_entry(@temp_dir)
    end

    test "#execute_command with init subcommand runs application validation generator for non-Rails app" do
      string_io = StringIO.new
      configuration = stub(
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
      configuration = stub(
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
  end
end
