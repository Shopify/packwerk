# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class PackageSetTest < Minitest::Test
    include RailsApplicationFixtureHelper

    setup do
      setup_application_fixture
    end

    teardown do
      teardown_application_fixture
    end

    test "#package_from_path returns package instance for a known path" do
      use_template(:skeleton)
      package_set = PackageSet.load_all_from(app_dir)

      assert_equal("components/timeline", package_set.package_from_path("components/timeline/something.rb").name)
    end

    test "#package_from_path returns root package for an unpackaged path" do
      use_template(:skeleton)
      package_set = PackageSet.load_all_from(app_dir)

      assert_equal(".", package_set.package_from_path("components/unknown/something.rb").name)
    end

    test "#package_from_path returns nested packages" do
      use_template(:skeleton)
      package_set = PackageSet.load_all_from(app_dir)

      assert_equal(
        "components/timeline/nested",
        package_set.package_from_path("components/timeline/nested/something.rb").name
      )
    end

    test "#package_from_path returns a package from an external package in autoload paths" do
      use_template(:external_packages)

      package_set = PackageSet.load_all_from(app_dir, scan_for_packages_outside_of_app_dir: true)
      assert_equal(
        package_set.package_from_path("../sales/components/sales/app/models/order.rb").name,
        "../sales/components/sales"
      )
    end

    test "#fetch returns a package instance for known package name" do
      use_template(:skeleton)
      package_set = PackageSet.load_all_from(app_dir)

      assert_equal("components/timeline", T.must(package_set.fetch("components/timeline")).name)
    end

    test "#fetch returns nil for unknown package name" do
      use_template(:skeleton)
      package_set = PackageSet.load_all_from(app_dir)

      assert_nil(package_set.fetch("components/unknown"))
    end
  end
end
