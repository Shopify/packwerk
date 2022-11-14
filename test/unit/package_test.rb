# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class PackageTest < Minitest::Test
    setup do
      @package = Package.new(name: "components/timeline", config: {})
    end

    test "#package_path? returns true for path under the package" do
      assert_equal(true, @package.package_path?("components/timeline/something.rb"))
    end

    test "#package_path? returns false for path not under the package" do
      assert_equal(false, @package.package_path?("components/unknown/something.rb"))
    end

    test "#package_path? returns true for path in root package" do
      root_package = Package.new(name: ".", config: {})
      assert_equal(true, root_package.package_path?("components/unknown"))
    end

    test "#<=> compares against name" do
      assert_equal(-1, @package <=> Package.new(name: "components/xyz", config: {}))
      assert_equal(0, @package <=> Package.new(name: "components/timeline", config: {}))
      assert_equal(1, @package <=> Package.new(name: "components/abc", config: {}))
    end

    test "#<=> does not compare against different class" do
      assert_nil(@package <=> "boop")
      assert_nil(@package <=> Hash.new(name: "boop"))
    end

    test "logical object equality is respected" do
      package = Package.new(name: "components/timeline", config: {})
      package2 = Package.new(name: "components/timeline", config: {})

      assert_equal package, package2

      hash = { package => "a" }
      assert_equal "a", hash[package2]
    end
  end
end
