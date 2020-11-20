# frozen_string_literal: true
require "test_helper"
require "rails_test_helper"
require "packwerk/commands/init"

module Packwerk
  module Commands
    class InitTest < Minitest::Test
      setup do
        @temp_dir = Dir.mktmpdir
      end

      teardown do
        FileUtils.remove_entry(@temp_dir)
      end

      test "#run runs application validation generator for non-Rails app" do
        string_io = StringIO.new
        configuration = stub(
          root_path: @temp_dir,
          load_paths: ["path"],
          package_paths: "**/",
          custom_associations: ["cached_belongs_to"],
          inflections_file: "config/inflections.yml"
        )

        Generators::ApplicationValidation.expects(:generate).returns(true)

        init_command = Commands::Init.new(
          out: string_io,
          configuration: configuration
        )

        assert init_command.run
        assert_includes string_io.string, "is ready to be used"
      end

      test "#run runs application validation generator, fails and prints error" do
        string_io = StringIO.new
        configuration = stub(
          root_path: @temp_dir,
          load_paths: ["path"],
          package_paths: "**/",
          custom_associations: ["cached_belongs_to"],
          inflections_file: "config/inflections.yml"
        )

        Generators::ApplicationValidation.expects(:generate).returns(false)

        init_command = Commands::Init.new(
          out: string_io,
          configuration: configuration
        )

        refute init_command.run
      end
    end
  end
end
