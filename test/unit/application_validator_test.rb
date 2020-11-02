# typed: false
# frozen_string_literal: true

require "test_helper"
require "rails_test_helper"
require "packwerk/application_validator"

# make sure PrivateThing.constantize succeeds to pass the privacy validity check
require "fixtures/skeleton/components/timeline/app/models/private_thing.rb"

# make sure the application has a chance to load its inflections
require "fixtures/skeleton/config/environment"

module Packwerk
  class ApplicationValidatorTest < Minitest::Test
    include FixtureHelper

    setup do
      @configuration = Packwerk::Configuration.from_path("test/fixtures/skeleton")
    end

    test "validity" do
      copy_template(:skeleton)
      result = validator.check_all
      assert result.ok?, result.error_value
    end

    test "check_autoload_path_cache fails on extraneous config load paths" do
      copy_template(:minimal)
      application_validator = Packwerk::ApplicationValidator.new(
        config_file_path: config.config_path,
        application_load_paths: [],
        configuration: config
      )

      result = application_validator.check_autoload_path_cache

      refute result.ok?, result.error_value
      assert_match /Extraneous load paths in file:.*components\/sales\/app\/models/m, result.error_value
    end

    test "check_autoload_path_cache fails on missing config load paths" do
      copy_template(:minimal)
      application_validator = Packwerk::ApplicationValidator.new(
        config_file_path: config.config_path,
        application_load_paths: ["components/sales/app/models", "components/timeline/app/models"],
        configuration: config
      )

      result = application_validator.check_autoload_path_cache

      refute result.ok?, result.error_value
      assert_match /Paths missing from file:.*components\/timeline\/app\/models/m, result.error_value
    end

    test "check_package_manifest_syntax returns an error for unknown package keys" do
      merge_into_yaml_file("package.yml", { "enforce_correctness" => false })
      result = validator.check_package_manifest_syntax
      refute result.ok?
      assert_match /Unknown keys/, result.error_value
    end

    test "check_package_manifest_syntax returns an error for invalid enforce_privacy value" do
      merge_into_yaml_file("package.yml", { "enforce_privacy" => "yes, please." })
      result = validator.check_package_manifest_syntax
      refute result.ok?
      assert_match /Invalid 'enforce_privacy' option/, result.error_value
    end

    test "check_package_manifests_for_privacy returns an error for unresolvable privatized constants" do
      copy_template(:minimal)
      merge_into_yaml_file("components/sales/package.yml", { "enforce_privacy" => ["Some::Constant"] })

      assert_raises(NameError) { validator.check_package_manifests_for_privacy }
    end

    test "returns error for mismatched inflections.yml file" do
      copy_template(:skeleton)
      merge_into_yaml_file("packwerk.yml", { "inflections_file" => "different_inflections.yml" })

      result = validator.check_all

      refute(result.ok?, result.error_value)
    end

    test "works for custom inflections file with inflections matching ActiveSupport" do
      copy_template(:skeleton)
      merge_into_yaml_file("packwerk.yml", { "inflections_file" => "custom_inflections.yml" })

      inflections = ActiveSupport::Inflector.inflections.deep_dup
      Packwerk::Inflections::Custom.new(
        path_to("custom_inflections.yml")
      ).apply_to(inflections)

      ActiveSupport::Inflector.expects(:inflections).returns(inflections).at_least_once

      result = validator.check_all

      assert(result.ok?, result.error_value)
    end

    test "check_acyclic_graph returns error when package set contains circular dependencies" do
      copy_template(:minimal)
      merge_into_yaml_file("components/sales/package.yml", { "dependencies" => ["components/timeline"] })
      merge_into_yaml_file("components/timeline/package.yml", { "dependencies" => ["components/sales"] })

      result = validator.check_acyclic_graph
      refute result.ok?
      assert_match /Expected the package dependency graph to be acyclic/, result.error_value
      assert_match /components\/sales → components\/timeline → components\/sales/, result.error_value
    end

    test "check_package_manifest_paths returns error when config only declares partial list of packages" do
      copy_template(:minimal)
      merge_into_yaml_file("components/timeline/package.yml", {})
      merge_into_yaml_file("packwerk.yml", { "package_paths" => ["components/sales","."] })

      result = validator.check_package_manifest_paths
      refute result.ok?
      assert_match /Expected package paths for all package.ymls to be specified/, result.error_value
      assert_match /manifests:\n\ncomponents\/timeline\/package.yml$/m, result.error_value
    end

    test "check_valid_package_dependencies returns error when config contains invalid package dependency" do
      copy_template(:minimal)
      merge_into_yaml_file("components/sales/package.yml", { "dependencies" => ["components/timeline"] })

      result = validator.check_valid_package_dependencies
      refute result.ok?
      assert_match /These dependencies do not point to valid packages:/, result.error_value
      assert_match /\n\ncomponents\/sales\/package.yml:\n  - components\/timeline\n\n$/m, result.error_value
    end

    test "check_root_package_exists returns error when root directory is missing a package.yml file" do
      copy_template(:minimal)
      remove_app_entry("package.yml")

      result = validator.check_root_package_exists
      refute result.ok?
      assert_match /A root package does not exist./, result.error_value
    end

    def validator
      @application_validator ||= Packwerk::ApplicationValidator.new(
        config_file_path: config.config_path,
        configuration: config
      )
    end
  end
end
