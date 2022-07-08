# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class PackageTest < Minitest::Test
    setup do
      @package = Package.new(name: "components/timeline", config: { "enforce_privacy" => ["::Test"] })
    end

    test "#enforce_privacy returns same value as from config" do
      assert_equal(["::Test"], @package.enforce_privacy)
    end

    test "#package_path? returns true for path under the package" do
      assert_equal(true, @package.package_path?("components/timeline/something.rb"))
    end

    test "#package_path? returns false for path not under the package" do
      assert_equal(false, @package.package_path?("components/unknown/something.rb"))
    end

    test "#package_path? returns true for path in root package" do
      root_package = Package.new(name: ".", config: { "enforce_privacy" => "::Test" })
      assert_equal(true, root_package.package_path?("components/unknown"))
    end

    test "#public_path returns expected path when using the default public path" do
      assert_equal("components/timeline/app/public/", @package.public_path)
    end

    test "#public_path returns expected path when using a user defined public path" do
      package = Package.new(name: "components/timeline", config: { "public_path" => "my/path/" })

      assert_equal("components/timeline/my/path/", package.public_path)
    end

    test "#public_path returns expected path when using the default public path in root package" do
      package = Package.new(name: ".", config: {})
      assert_equal("app/public/", package.public_path)
    end

    test "#public_path returns expected path when using a user defined public path" do
      package = Package.new(name: ".", config: { "public_path" => "my/path/" })

      assert_equal("my/path/", package.public_path)
    end

    test "#package_path? returns true for path under the package's public path" do
      assert_equal(true, @package.public_path?("components/timeline/app/public/entrypoint.rb"))
    end

    test "#package_path? returns false for path not under the package's public path" do
      assert_equal(false, @package.public_path?("components/timeline/app/models/something.rb"))
    end

    test "#public_path? returns true for path under the root package's public path" do
      package = Package.new(name: ".", config: {})
      assert_equal(true, package.public_path?("app/public/entrypoint.rb"))
    end

    test "#public_path? returns false for path not under the root package's public path" do
      package = Package.new(name: ".", config: {})
      assert_equal(false, package.public_path?("app/models/something.rb"))
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

    test "#user_defined_public_path returns nil when not set in the configuration" do
      assert_nil(@package.user_defined_public_path)
    end

    test "#user_defined_public_path returns the same value as in the config when set" do
      package = Package.new(name: "components/timeline", config: { "public_path" => "my/path/" })

      assert_equal("my/path/", package.user_defined_public_path)
    end

    test "#user_defined_public_path adds a trailing forward slash to the path if it does not exist" do
      package = Package.new(name: "components/timeline", config: { "public_path" => "my/path" })

      assert_equal("my/path/", package.user_defined_public_path)
    end

    test "logical object equality is respected" do
      package = Package.new(name: "components/timeline", config: { "public_path" => "my/path" })
      package2 = Package.new(name: "components/timeline", config: { "public_path" => "my/path" })

      assert_equal package, package2

      hash = { package => "a" }
      assert_equal "a", hash[package2]
    end
  end
end
