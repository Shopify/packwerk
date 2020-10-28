# typed: ignore
# frozen_string_literal: true

require "test_helper"
require "packwerk/fixture_reference_inspector"
require "parser_test_helper"

module Packwerk
  class FixtureReferenceInspectorTest < ActiveSupport::TestCase
    setup do
      @inspector = FixtureReferenceInspector.new(
        root_path: "test/fixtures/fixture_reference_inspector",
        fixture_paths: ["test/fixtures"]
      )
    end

    test "#constant_name_from_node extracts constant names from fixtures" do
      node = parse("orders :snowdevil")

      constant_name = @inspector.constant_name_from_node(node, ancestors: [])

      assert_equal "::Order", constant_name
    end

    test "#constant_name_from_node extracts constant names from fixtures when nested" do
      node = parse("sales_orders :snowdevil")

      constant_name = @inspector.constant_name_from_node(node, ancestors: [])

      assert_equal "::Sales::Order", constant_name
    end

    test "#constant_name_from_node extracts constant names from fixtures when model_class is set directly in the YAML file" do
      node = parse("order_errors :snowdevil")

      constant_name = @inspector.constant_name_from_node(node, ancestors: [])

      assert_equal "::Sales::Order::Error", constant_name
    end

    test "#constant_name_from_node returns nil when the two or more arguments are passed" do
      node = parse("orders :snowdevil, :foo")

      constant_name = @inspector.constant_name_from_node(node, ancestors: [])

      assert_nil constant_name
    end

    test "#constant_name_from_node returns nil when a non symbol argument is passed" do
      node = parse("orders 10")

      constant_name = @inspector.constant_name_from_node(node, ancestors: [])

      assert_nil constant_name
    end

    test "#constant_name_from_node returns nil when the YAML does not exist" do
      node = parse("not_a_fixture :foo")

      constant_name = @inspector.constant_name_from_node(node, ancestors: [])

      assert_nil constant_name
    end

    def parse(statement)
      ParserTestHelper.parse(statement)
    end
  end
end
