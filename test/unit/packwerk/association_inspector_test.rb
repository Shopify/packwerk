# typed: true
# frozen_string_literal: true

require "test_helper"
require "support/packwerk/parser_test_helper"

module Packwerk
  class AssociationInspectorTest < Minitest::Test
    setup do
      @inflector = ActiveSupport::Inflector
    end

    test "#association? understands custom associations" do
      node = parse("has_lots :order")
      inspector = AssociationInspector.new(inflector: @inflector, custom_associations: [:has_lots])

      assert_equal "Order", inspector.constant_name_from_node(node, ancestors: [], relative_file: "")
    end

    test "finds target constant for simple association" do
      node = parse("has_one :order")
      inspector = AssociationInspector.new(inflector: @inflector)

      assert_equal "Order", inspector.constant_name_from_node(node, ancestors: [], relative_file: "")
    end

    test "finds target constant for association that pluralizes" do
      node = parse("has_many :orders")
      inspector = AssociationInspector.new(inflector: @inflector)

      assert_equal "Order", inspector.constant_name_from_node(node, ancestors: [], relative_file: "")
    end

    test "finds target constant for association if explicitly specified" do
      node = parse("has_one :cool_order, { class_name: 'Order' }")
      inspector = AssociationInspector.new(inflector: @inflector)

      assert_equal "Order", inspector.constant_name_from_node(node, ancestors: [], relative_file: "")
    end

    test "rejects method calls that are not associations" do
      node = parse('puts "Hello World"')
      inspector = AssociationInspector.new(inflector: @inflector)

      assert_nil inspector.constant_name_from_node(node, ancestors: [], relative_file: "")
    end

    test "gives up on metaprogrammed associations" do
      node = parse("has_one association_name")
      inspector = AssociationInspector.new(inflector: @inflector)

      assert_nil inspector.constant_name_from_node(node, ancestors: [], relative_file: "")
    end

    test "gives up on dynamic class name" do
      node = parse("has_one :order, class_name: Order.name")
      inspector = AssociationInspector.new(inflector: @inflector)

      assert_nil inspector.constant_name_from_node(node, ancestors: [], relative_file: "")
    end

    test "gives up on excluded file node" do
      node = parse("has_one :order")
      inspector = AssociationInspector.new(
        inflector: @inflector, excluded_files: Set["app/serializers/my_serializer.rb"]
      )

      assert_nil inspector.constant_name_from_node(
        node,
        ancestors: [],
        relative_file: "app/serializers/my_serializer.rb",
      )
    end

    private

    def parse(statement)
      ParserTestHelper.parse(statement)
    end
  end
end
