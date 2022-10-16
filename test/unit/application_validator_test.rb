# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class ApplicationValidatorTest < Minitest::Test
    extend T::Sig
    include RailsApplicationFixtureHelper

    setup do
      setup_application_fixture
    end

    teardown do
      teardown_application_fixture
    end

    test "validity" do
      use_template(:skeleton)

      result = validator.check_all

      assert result.ok?, result.error_value
    end

    test "check_package_manifest_syntax returns an error for unknown package keys" do
      use_template(:minimal)
      merge_into_app_yaml_file("package.yml", { "enforce_correctness" => false })

      result = validator.check_package_manifest_syntax

      refute result.ok?
      assert_match(/Unknown keys/, result.error_value)
    end

    test "check_package_manifest_syntax returns an error for invalid enforce_dependencies value" do
      use_template(:minimal)
      merge_into_app_yaml_file("package.yml", { "enforce_dependencies" => "components/sales" })

      result = validator.check_package_manifest_syntax

      refute result.ok?
      assert_match(/Invalid 'enforce_dependencies' option/, result.error_value)
    end

    test "check_package_manifest_syntax returns error for invalid dependencies value" do
      use_template(:minimal)
      merge_into_app_yaml_file("components/timeline/package.yml", {})
      merge_into_app_yaml_file("components/sales/package.yml", { "dependencies" => "components/timeline" })

      result = validator.check_package_manifest_syntax

      refute result.ok?
      assert_match(/Invalid 'dependencies' option/, result.error_value)
    end

    test "check_acyclic_graph returns error when package set contains circular dependencies" do
      use_template(:minimal)
      merge_into_app_yaml_file("components/sales/package.yml", { "dependencies" => ["components/timeline"] })
      merge_into_app_yaml_file("components/timeline/package.yml", { "dependencies" => ["components/sales"] })

      result = validator.check_acyclic_graph

      refute result.ok?
      assert_match(/Expected the package dependency graph to be acyclic/, result.error_value)
      assert_match %r{components/sales → components/timeline → components/sales}, result.error_value
    end

    test "check_package_manifest_paths returns error when config only declares partial list of packages" do
      use_template(:minimal)
      merge_into_app_yaml_file("components/timeline/package.yml", {})
      merge_into_app_yaml_file("packwerk.yml", { "package_paths" => ["components/sales", "."] })

      result = validator.check_package_manifest_paths

      refute result.ok?
      assert_match(/Expected package paths for all package.ymls to be specified/, result.error_value)
      assert_match %r{manifests:\n\ncomponents/timeline/package.yml$}m, result.error_value
    end

    test "check_package_manifest_paths returns no error when vendor/**/* is excluded" do
      use_template(:skeleton)
      merge_into_app_yaml_file("components/timeline/package.yml", {})
      merge_into_app_yaml_file("packwerk.yml", { "package_paths" => ["components/**/*", "."] })
      merge_into_app_yaml_file("packwerk.yml", { "exclude" => ["vendor/**/*"] })

      package_paths = PackageSet.package_paths(".", "**")
      vendor_package_path = Pathname.new("vendor/cache/gems/example/package.yml")
      assert_includes(package_paths, vendor_package_path)

      result = validator.check_package_manifest_paths

      assert result.ok?
      refute result.error_value
    end

    test "check_valid_package_dependencies returns error when config contains invalid package dependency" do
      use_template(:minimal)
      merge_into_app_yaml_file("components/sales/package.yml", { "dependencies" => ["components/timeline"] })

      result = validator.check_valid_package_dependencies

      refute result.ok?
      assert_match(/These dependencies do not point to valid packages:/, result.error_value)
      assert_match %r{\n\ncomponents/sales/package.yml:\n  - components/timeline\n\n$}m, result.error_value
    end

    test "check_root_package_exists returns error when root directory is missing a package.yml file" do
      use_template(:minimal)
      remove_app_entry("package.yml")

      result = validator.check_root_package_exists
      refute result.ok?
      assert_match(/A root package does not exist./, result.error_value)
    end

    sig { returns(Packwerk::ApplicationValidator) }
    def validator
      @application_validator ||= Packwerk::ApplicationValidator.new(
        config_file_path: config.config_path,
        configuration: config,
        environment: "test"
      )
    end
  end
end
