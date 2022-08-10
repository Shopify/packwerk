# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class PackagePathsTest < Minitest::Test
    include RailsApplicationFixtureHelper

    setup do
      setup_application_fixture
    end

    teardown do
      teardown_application_fixture
    end

    test "#all_paths supports a path wildcard" do
      use_template(:skeleton)
      package_paths = PackagePaths.new(".", "**")

      assert_includes(package_paths.all_paths, Pathname.new("components/sales/package.yml"))
      assert_includes(package_paths.all_paths, Pathname.new("package.yml"))
    end

    test "#all_paths supports a single path as a string" do
      use_template(:skeleton)
      package_paths = PackagePaths.new(".", "components/sales")

      assert_equal(package_paths.all_paths, [Pathname.new("components/sales/package.yml")])
    end

    test "#all_paths supports many paths as an array" do
      use_template(:skeleton)
      package_paths = PackagePaths.new(".", ["components/sales", "."])

      assert_equal(
        package_paths.all_paths,
        [
          Pathname.new("components/sales/package.yml"),
          Pathname.new("package.yml"),
        ]
      )
    end

    test "#all_paths excludes paths inside the gem directory" do
      use_template(:skeleton)
      vendor_package_path = Pathname.new("vendor/cache/gems/example/package.yml")

      package_paths = PackagePaths.new(".", "**")
      assert_includes(package_paths.all_paths, vendor_package_path)

      Bundler.expects(:bundle_path).once.returns(Rails.root.join("vendor/cache/gems"))
      package_paths = PackagePaths.new(".", "**")
      refute_includes(package_paths.all_paths, vendor_package_path)
    end

    test "#all_paths excludes paths in exclude pathspec" do
      use_template(:skeleton)
      vendor_package_path = Pathname.new("vendor/cache/gems/example/package.yml")

      package_paths = PackagePaths.new(".", "**")
      assert_includes(package_paths.all_paths, vendor_package_path)

      package_paths = PackagePaths.new(".", "**", "vendor/*")
      refute_includes(package_paths.all_paths, vendor_package_path)
    end

    test "#all_paths excludes paths in multiple exclude pathspecs" do
      use_template(:skeleton)

      vendor_package_path = Pathname.new("vendor/cache/gems/example/package.yml")
      sales_package_path = Pathname.new("components/sales/package.yml")

      package_paths = PackagePaths.new(".", "**")
      assert_includes(package_paths.all_paths, vendor_package_path)
      assert_includes(package_paths.all_paths, sales_package_path)

      package_paths = PackagePaths.new(".", "**", ["vendor/*", "components/sales/*"])
      refute_includes(package_paths.all_paths, vendor_package_path)
      refute_includes(package_paths.all_paths, sales_package_path)
    end

    test "#all_paths ignores empty excludes" do
      use_template(:skeleton)

      assert_equal(
        PackagePaths.new(".", "**").all_paths,
        PackagePaths.new(".", "**", []).all_paths
      )
    end
  end
end
