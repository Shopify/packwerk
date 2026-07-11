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
      assert_equal [:custom_association], configuration.custom_associations
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
      empty_config = Configuration.new

      Configuration.expects(:new).with({}, config_path: to_app_path("packwerk.yml")).returns(empty_config)
      Configuration.from_path
    end

    test "require works when referencing a local file" do
      refute defined?(MyLocalExtension)
      use_template(:extended)
      mock_require_method = ->(required_thing) do
        next unless required_thing.include?("my_local_extension")

        require required_thing
      end
      ExtensionLoader.stub(:require, mock_require_method) do
        Configuration.from_path
      end
      assert defined?(MyLocalExtension)

      remove_extensions
    end

    test "#load_paths uses explicitly configured load_paths and never boots Rails" do
      use_template(:minimal)
      merge_into_app_yaml_file("packwerk.yml", { "load_paths" => ["components/sales/app/models"] })

      RailsLoadPaths.expects(:for).never

      configuration = Configuration.from_path(app_dir)

      assert_equal({ "components/sales/app/models" => Object }, configuration.load_paths)
    end

    test "#load_paths expands globs in configured load_paths" do
      use_template(:minimal)
      merge_into_app_yaml_file("packwerk.yml", { "load_paths" => ["components/*/app/models"] })

      configuration = Configuration.from_path(app_dir)

      assert_equal({ "components/sales/app/models" => Object }, configuration.load_paths)
    end

    test "#load_paths deduplicates paths matched by overlapping entries" do
      use_template(:minimal)
      merge_into_app_yaml_file("packwerk.yml", {
        "load_paths" => ["components/sales/app/models", "components/*/app/models"],
      })

      configuration = Configuration.from_path(app_dir)

      assert_equal({ "components/sales/app/models" => Object }, configuration.load_paths)
    end

    test "#load_paths falls back to RailsLoadPaths when no load_paths are configured" do
      use_template(:minimal)
      expected = { "app" => Object }
      RailsLoadPaths.expects(:for).with(app_dir, environment: "test").returns(expected)

      configuration = Configuration.from_path(app_dir)

      assert_equal(expected, configuration.load_paths)
    end

    test "#load_paths raises a helpful error when not a Rails app and no load_paths are configured" do
      use_template(:blank)

      configuration = Configuration.from_path(app_dir)

      error = assert_raises(RuntimeError) { configuration.load_paths }
      assert_match(/load_paths/, error.message)
      assert_match(%r{config/environment\.rb}, error.message)
    end

    test "#load_paths raises when configured load_paths match no directories" do
      use_template(:minimal)
      merge_into_app_yaml_file("packwerk.yml", { "load_paths" => ["does_not_exist/**"] })

      configuration = Configuration.from_path(app_dir)

      error = assert_raises(RuntimeError) { configuration.load_paths }
      assert_match(/did not match any directories/, error.message)
    end

    test "raises when load_paths is not a list of strings" do
      use_template(:minimal)
      merge_into_app_yaml_file("packwerk.yml", { "load_paths" => "app" })

      assert_raises(ArgumentError) { Configuration.from_path(app_dir) }
    end

    test "require works when referencing a gem" do
      use_template(:extended)

      required_things = []
      mock_require_method = ->(required_thing) do
        required_things << required_thing
      end
      ExtensionLoader.stub(:require, mock_require_method) do
        Configuration.from_path
      end

      assert_includes(required_things, "my_gem_extension")
    end
  end
end
