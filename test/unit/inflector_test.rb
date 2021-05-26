# typed: false
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class InflectorTest < Minitest::Test
    def setup
      @inflector = inflector_for(file: "config/inflections.yml")
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

    test "#initialize will apply custom inflections from file" do
      inflector = inflector_for(file: "test/fixtures/skeleton/custom_inflections.yml")

      assert_equal "graphql", inflector.underscore("GraphQL")
      assert_equal "payment_details", inflector.singularize("payment_details")
    end

    test "#initialize will not apply custom inflections if there aren't any" do
      inflector = inflector_for(file: "no_inflections_here.yml")

      assert_equal "graph_ql", inflector.underscore("GraphQL")
      assert_equal "payment_detail", inflector.singularize("payment_details")
    end

    private

    def inflector_for(file:)
      custom_inflector = Packwerk::Inflections::Custom.new(file)
      Inflector.new(custom_inflector: custom_inflector)
    end
  end
end
