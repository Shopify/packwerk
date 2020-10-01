# typed: ignore
# frozen_string_literal: true

require "test_helper"
require "rails_test_helper"

module Packwerk
  class ConfigurationTest < Minitest::Test
    test ".from_path raises ArgumentError if path does not exist" do
      File.expects(:exist?).with("foo").returns(false)
      error = assert_raises ArgumentError do
        Configuration.from_path("foo")
      end

      assert_equal("#{File.expand_path('foo')} does not exist", error.message)
    end

    test ".from_path uses packwerk config when it exists" do
      File.expects(:exist?).with(".").returns(true)
      File.expects(:file?).with("./packwerk.yml").returns(true)

      configuration_hash = {
        "include" => ["xyz/*.rb"],
        "exclude" => ["{exclude_dir,bin,tmp}/**/*"],
        "package_paths" => "**/*/",
        "load_paths" => ["app/models"],
        "custom_associations" => ["custom_association"],
        "inflections_file" => "custom_inflections.yml",
      }
      YAML.expects(:load_file).with("./packwerk.yml").returns(configuration_hash)

      configuration = Configuration.from_path(".")

      assert_equal ["xyz/*.rb"], configuration.include
      assert_equal ["{exclude_dir,bin,tmp}/**/*"], configuration.exclude
      assert_equal File.expand_path("."), configuration.root_path
      assert_equal ["app/models"], configuration.load_paths
      assert_equal "**/*/", configuration.package_paths
      assert_equal ["custom_association"], configuration.custom_associations
      assert_equal File.expand_path("custom_inflections.yml"), configuration.inflections_file
    end

    test ".from_path falls back to some default config when no existing config exists" do
      File.expects(:exist?).with(Dir.pwd).returns(true)
      File.expects(:file?).with(File.join(Dir.pwd, "packwerk.yml")).returns(false)

      configuration = Configuration.from_path

      assert_equal ["**/*.{rb,rake,erb}"], configuration.include
      assert_equal ["{bin,node_modules,script,tmp}/**/*"], configuration.exclude
      assert_equal File.expand_path("."), configuration.root_path
      assert_equal default_autoloads, configuration.load_paths.sort
      assert_equal "**/", configuration.package_paths
      assert_empty configuration.custom_associations
      assert_equal File.expand_path("config/inflections.yml"), configuration.inflections_file
    end

    test ".from_path doesn't include load paths from vendored gems" do
      File.expects(:exist?).with(Dir.pwd).returns(true)
      File.expects(:file?).with(File.join(Dir.pwd, "packwerk.yml")).returns(false)
      Bundler.expects(:bundle_path).returns(Rails.root.join("vendor/cache/gems"))

      configuration = Configuration.from_path
      expected_autoloads = default_autoloads - ["vendor/cache/gems/example/models"]

      assert_equal expected_autoloads, configuration.load_paths.sort
    end

    private

    # TODO: this isn't great, so let's come back and refactor so that we're in more control
    #       of the initial state.
    def default_autoloads
      [
        "components/platform/app/models",
        "components/sales/app/models",
        "components/timeline/app/models",
        "components/timeline/app/models/concerns",
        "vendor/cache/gems/example/models",
      ]
    end
  end
end
