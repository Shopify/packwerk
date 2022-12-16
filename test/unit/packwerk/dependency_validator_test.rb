# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class DependencyValidatorTest < Minitest::Test
    include FactoryHelper
    include RailsApplicationFixtureHelper

    setup do
      setup_application_fixture
    end

    teardown do
      teardown_application_fixture
    end

    test "returns error when package set contains circular dependencies" do
      use_template(:minimal)
      merge_into_app_yaml_file("components/sales/package.yml", { "dependencies" => ["components/timeline"] })
      merge_into_app_yaml_file("components/timeline/package.yml", { "dependencies" => ["components/sales"] })

      result = dependency_validator.call(package_set, config)

      refute result.ok?
      assert_match(/Expected the package dependency graph to be acyclic/, result.error_value)
      assert_match %r{components/sales → components/timeline → components/sales}, result.error_value
    end

    test "returns error when config contains invalid package dependency" do
      use_template(:minimal)
      merge_into_app_yaml_file("components/sales/package.yml", { "dependencies" => ["components/timeline"] })

      result = dependency_validator.call(package_set, config)

      refute result.ok?
      assert_match(/These dependencies do not point to valid packages:/, result.error_value)
      assert_match(%r{\n\n\tcomponents/sales/package.yml:\n\t  - components/timeline\n$}m, result.error_value)
    end

    test "returns error when invalid enforce_dependencies value is in the package.yml file" do
      use_template(:minimal)
      merge_into_app_yaml_file("components/sales/package.yml", { "enforce_dependencies" => "yes" })

      result = dependency_validator.call(package_set, config)
      refute result.ok?
      assert_match("Malformed syntax in the following manifests:", result.error_value)
      assert_match("Invalid 'enforce_dependencies' option: \"yes\"", result.error_value)
    end

    test "returns error when invalid dependencies value is in the package.yml file" do
      use_template(:minimal)
      merge_into_app_yaml_file("components/sales/package.yml", { "dependencies" => "yes" })

      result = dependency_validator.call(package_set, config)
      refute result.ok?
      assert_match("Malformed syntax in the following manifests:", result.error_value)
      assert_match("Invalid 'dependencies' option: \"yes\"", result.error_value)
    end

    test "returns success when enforce_dependencies is set to strict in the package.yml file" do
      use_template(:minimal)
      merge_into_app_yaml_file("components/sales/package.yml", { "enforce_dependencies" => "strict" })

      result = dependency_validator.call(package_set, config)
      assert result.ok?
    end

    private

    def dependency_validator
      Validators::DependencyValidator.new
    end
  end
end
