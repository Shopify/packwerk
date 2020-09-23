# typed: ignore
# frozen_string_literal: true

require "test_helper"
require "parser_test_helper"

module Packwerk
  class AssociationInspectorTest < Minitest::Test
    test "#association? understands custom associations" do
      node = parse("has_lots :order")
      inspector = AssociationInspector.new(custom_associations: [:has_lots])

      assert_equal "Order", inspector.constant_name_from_node(node, ancestors: [])
    end

    test "finds target constant for simple association" do
      node = parse("has_one :order")
      inspector = AssociationInspector.new

      assert_equal "Order", inspector.constant_name_from_node(node, ancestors: [])
    end

    test "finds target constant for association that pluralizes" do
      node = parse("has_many :orders")
      inspector = AssociationInspector.new

      assert_equal "Order", inspector.constant_name_from_node(node, ancestors: [])
    end

    test "finds target constant for association if explicitly specified" do
      node = parse("has_one :cool_order, { class_name: 'Order' }")
      inspector = AssociationInspector.new

      assert_equal "Order", inspector.constant_name_from_node(node, ancestors: [])
    end

    test "rejects method calls that are not associations" do
      node = parse('puts "Hello World"')
      inspector = AssociationInspector.new

      assert_nil inspector.constant_name_from_node(node, ancestors: [])
    end

    test "gives up on metaprogrammed associations" do
      node = parse("has_one association_name")
      inspector = AssociationInspector.new

      assert_nil inspector.constant_name_from_node(node, ancestors: [])
    end

    test "gives up on dynamic class name" do
      node = parse("has_one :order, class_name: Order.name")
      inspector = AssociationInspector.new

      assert_nil inspector.constant_name_from_node(node, ancestors: [])
    end

    private

    def parse(statement)
      ParserTestHelper.parse(statement)
    end
  end
end
