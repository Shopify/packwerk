# frozen_string_literal: true
require "test_helper"
require "rails_test_helper"
require "packwerk/commands/generate_configs"

module Packwerk
  module Commands
    class GenerateConfigsTest < Minitest::Test
      test "#run generates configurations file, inflections file and root package" do
        string_io = StringIO.new
        configuration = stub(
          root_path: @temp_dir,
          load_paths: ["path"],
          package_paths: "**/",
          custom_associations: ["cached_belongs_to"],
          inflections_file: "config/inflections.yml"
        )

        Generators::ConfigurationFile.expects(:generate).returns(true)
        Generators::InflectionsFile.expects(:generate).returns(true)
        Generators::RootPackage.expects(:generate).returns(true)

        generate_configs_command = Commands::GenerateConfigs.new(
          out: string_io,
          configuration: configuration
        )

        assert generate_configs_command.run
        assert_includes string_io.string, "is ready to be used"
      end

      test "#run fails and prints error" do
        string_io = StringIO.new
        configuration = stub(
          root_path: @temp_dir,
          load_paths: ["path"],
          package_paths: "**/",
          custom_associations: ["cached_belongs_to"],
          inflections_file: "config/inflections.yml"
        )

        Generators::ConfigurationFile.expects(:generate).returns(true)
        Generators::InflectionsFile.expects(:generate).returns(true)
        Generators::RootPackage.expects(:generate).returns(false)

        generate_configs_command = Commands::GenerateConfigs.new(
          out: string_io,
          configuration: configuration
        )

        refute generate_configs_command.run
        assert_includes string_io.string, "is not ready to be used"
      end
    end
  end
end
