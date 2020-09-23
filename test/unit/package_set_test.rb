# typed: ignore
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class PackageSetTest < Minitest::Test
    setup do
      @package_set = PackageSet.load_all_from("test/fixtures/skeleton/")
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
  end
end
