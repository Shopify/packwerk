# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class ConfigurationTest < Minitest::Test
    include ApplicationFixtureHelper

    setup do
      setup_application_fixture
    end

    teardown do
      teardown_application_fixture
    end

    test ".from_path raises ArgumentError if path does not exist" do
      File.expects(:exist?).with("foo").returns(false)
      error = assert_raises(ArgumentError) do
        Configuration.from_path("foo")
      end

      assert_equal("#{File.expand_path("foo")} does not exist", error.message)
    end

    test ".from_path uses packwerk config when it exists" do
      use_template(:minimal)
      remove_app_entry("packwerk.yml")

      configuration_hash = {
        "include" => ["xyz/*.rb"],
        "exclude" => ["{exclude_dir,bin,tmp}/**/*"],
        "package_paths" => "**/*/",
        "custom_associations" => ["custom_association"],
      }
      merge_into_app_yaml_file("packwerk.yml", configuration_hash)

      configuration = Configuration.from_path(app_dir)

      assert_equal ["xyz/*.rb"], configuration.include
      assert_equal ["{exclude_dir,bin,tmp}/**/*"], configuration.exclude
      assert_equal app_dir, configuration.root_path
      assert_equal "**/*/", configuration.package_paths
      assert_equal ["custom_association"], configuration.custom_associations
    end

    test ".from_path falls back to some default config when no existing config exists" do
      use_template(:minimal)
      remove_app_entry("packwerk.yml")

      configuration = Configuration.from_path

      assert_equal ["**/*.{rb,rake,erb}"], configuration.include
      assert_equal ["{bin,node_modules,script,tmp,vendor}/**/*"], configuration.exclude
      assert_equal app_dir, configuration.root_path
      assert_equal "**/", configuration.package_paths
      assert_empty configuration.custom_associations
    end

    test ".from_path falls back to empty config when existing config is an empty document" do
      use_template(:blank)
      Configuration.expects(:new).with({}, config_path: to_app_path("packwerk.yml"))
      Configuration.from_path
    end
  end
end
