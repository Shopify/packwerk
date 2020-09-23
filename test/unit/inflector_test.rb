# typed: false
# frozen_string_literal: true

require "test_helper"

require "packwerk/inflector"

module Packwerk
  class InflectorTest < Minitest::Test
    def setup
      @inflector = Inflector.new
    end

    test "acts like activesupport inflector" do
      assert_operator Inflector.ancestors, :include?, ActiveSupport::Inflector
    end

    test "uses default inflections" do
      assert_equal(
        "Order",
        @inflector.classify("orders")
      )

      assert_equal(
        "Ox",
        @inflector.classify("oxen")
      )
    end

    test "#pluralize will pluralize when count not 1" do
      assert_equal "things", @inflector.pluralize("thing", 3)
      assert_equal "things", @inflector.pluralize("thing", -5)
      assert_equal "things", @inflector.pluralize("thing", 0)
      assert_equal "things", @inflector.pluralize("things", 1000)
    end

    test "#pluralize will singularize when count is 1" do
      assert_equal "thing", @inflector.pluralize("thing", 1)
      assert_equal "thing", @inflector.pluralize("things", 1)
    end
  end
end
