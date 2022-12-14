# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class PackageSetTest < Minitest::Test
    include RailsApplicationFixtureHelper

    setup do
      setup_application_fixture
      use_template(:skeleton)
      @package_set = PackageSet.load_all_from(app_dir)
    end

    teardown do
      teardown_application_fixture
    end

    test "#package_from_path returns package instance for a known path" do
      assert_equal("components/timeline", @package_set.package_from_path("components/timeline/something.rb").name)
    end

    test "#package_from_path returns root package for an unpackaged path" do
      assert_equal(".", @package_set.package_from_path("components/unknown/something.rb").name)
    end

    test "#package_from_path returns nested packages" do
      assert_equal(
        "components/timeline/nested",
        @package_set.package_from_path("components/timeline/nested/something.rb").name
      )
    end

    test "#fetch returns a package instance for known package name" do
      assert_equal("components/timeline", @package_set.fetch("components/timeline").name)
    end

    test "#fetch returns nil for unknown package name" do
      assert_nil(@package_set.fetch("components/unknown"))
    end

    test ".package_paths supports a path wildcard" do
      package_paths = PackageSet.package_paths(".", "**")

      assert_includes(package_paths, Pathname.new("components/sales/package.yml"))
      assert_includes(package_paths, Pathname.new("package.yml"))
    end

    test ".package_paths supports a single path as a string" do
      package_paths = PackageSet.package_paths(".", "components/sales")

      assert_equal(package_paths, [Pathname.new("components/sales/package.yml")])
    end

    test ".package_paths supports many paths as an array" do
      package_paths = PackageSet.package_paths(".", ["components/sales", "."])

      assert_equal(
        package_paths,
        [
          Pathname.new("components/sales/package.yml"),
          Pathname.new("package.yml"),
        ]
      )
    end

    test ".package_paths excludes paths inside the gem directory" do
      vendor_package_path = Pathname.new("vendor/cache/gems/example/package.yml")

      package_paths = PackageSet.package_paths(".", "**")
      assert_includes(package_paths, vendor_package_path)

      Bundler.expects(:bundle_path).returns(Rails.root.join("vendor/cache/gems"))
      package_paths = PackageSet.package_paths(".", "**")
      refute_includes(package_paths, vendor_package_path)
    end

    test ".package_paths excludes paths in exclude pathspec" do
      vendor_package_path = Pathname.new("vendor/cache/gems/example/package.yml")

      package_paths = PackageSet.package_paths(".", "**")
      assert_includes(package_paths, vendor_package_path)

      package_paths = PackageSet.package_paths(".", "**", "vendor/*")
      refute_includes(package_paths, vendor_package_path)
    end

    test ".package_paths excludes paths in multiple exclude pathspecs" do
      vendor_package_path = Pathname.new("vendor/cache/gems/example/package.yml")
      sales_package_path = Pathname.new("components/sales/package.yml")

      package_paths = PackageSet.package_paths(".", "**")
      assert_includes(package_paths, vendor_package_path)
      assert_includes(package_paths, sales_package_path)

      package_paths = PackageSet.package_paths(".", "**", ["vendor/*", "components/sales/*"])
      refute_includes(package_paths, vendor_package_path)
      refute_includes(package_paths, sales_package_path)
    end

    test ".package_paths ignores empty excludes" do
      assert_equal(
        PackageSet.package_paths(".", "**"),
        PackageSet.package_paths(".", "**", [])
      )
    end
  end
end
