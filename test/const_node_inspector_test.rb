# typed: true
# frozen_string_literal: true

require "test_helper"
require "parser_test_helper"

module Packwerk
  class ConstNodeInspectorTest < ActiveSupport::TestCase
    setup do
      @inspector = ConstNodeInspector.new
    end

    test "#constant_name_from_node should ignore any non-const nodes" do
      node = parse("a = 1 + 1")

      constant_name = @inspector.constant_name_from_node(node, ancestors: [])

      assert_nil constant_name
    end

    test "#constant_name_from_node should return correct name for const node" do
      node = parse("Order")

      constant_name = @inspector.constant_name_from_node(node, ancestors: [])

      assert_equal "Order", constant_name
    end

    test "#constant_name_from_node should return correct name for fully-qualified const node" do
      node = parse("::Order")

      constant_name = @inspector.constant_name_from_node(node, ancestors: [])

      assert_equal "::Order", constant_name
    end

    test "#constant_name_from_node should return correct name for compact const node" do
      node = parse("Sales::Order")

      constant_name = @inspector.constant_name_from_node(node, ancestors: [])

      assert_equal "Sales::Order", constant_name
    end

    test "#constant_name_from_node should return correct name for simple class definition" do
      parent = parse("class Order; end")
      node = NodeHelpers.each_child(parent).entries[0]

      constant_name = @inspector.constant_name_from_node(node, ancestors: [parent])

      assert_equal "::Order", constant_name
    end

    test "#constant_name_from_node should return correct name for nested and compact class definition" do
      grandparent = parse("module Foo::Bar; class Sales::Order; end; end")
      parent = NodeHelpers.each_child(grandparent).entries[1] # module node; second child is the body of the module
      node = NodeHelpers.each_child(parent).entries[0] # class node; first child is constant

      constant_name = @inspector.constant_name_from_node(node, ancestors: [parent, grandparent])

      assert_equal "::Foo::Bar::Sales::Order", constant_name
    end

    test "#constant_name_from_node should gracefully return nil for dynamically namespaced constants" do
      grandparent = parse("module CsvExportSharedTests; setup do self.class::HEADERS end; end")
      parent = NodeHelpers.each_child(grandparent).entries[1] # setup do self.class::HEADERS end
      node = NodeHelpers.each_child(parent).entries[2] # self.class::HEADERS

      constant_name = @inspector.constant_name_from_node(node, ancestors: [parent, grandparent])

      assert_nil constant_name
    end

    private

    def parse(code)
      ParserTestHelper.parse(code)
    end
  end
end
