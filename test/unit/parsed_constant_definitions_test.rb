# typed: ignore
# frozen_string_literal: true

require "test_helper"
require "parser_test_helper"

require "packwerk/node"

module Packwerk
  class ParsedConstantDefinitionsTest < Minitest::Test
    test "recognizes constant assignment" do
      definitions = ParsedConstantDefinitions.new(
        root_node: parse_code('HELLO = "World"')
      )

      assert definitions.local_reference?("HELLO")
    end

    test "recognizes class or module definitions" do
      definitions = ParsedConstantDefinitions.new(
        root_node: parse_code("module Sales; class Order; end; end")
      )

      assert definitions.local_reference?("Sales")
      assert definitions.local_reference?("Order", namespace_path: ["Sales"])
    end

    test "recognizes constants that are more fully qualified" do
      definitions = ParsedConstantDefinitions.new(
        root_node: parse_code('module Sales; HELLO = "World"; end')
      )

      assert definitions.local_reference?("HELLO", namespace_path: ["Sales"])
      assert definitions.local_reference?("Sales::HELLO")
      assert definitions.local_reference?("::Sales::HELLO")
    end

    test "understands fully qualified references" do
      definitions = ParsedConstantDefinitions.new(
        root_node: parse_code("module Sales; class Order; end; end")
      )

      assert definitions.local_reference?("::Sales")
      assert definitions.local_reference?("::Sales", namespace_path: ["Sales"])
      refute definitions.local_reference?("::Order")
      refute definitions.local_reference?("::Order", namespace_path: ["Sales"])
    end

    test "recognizes compact nested constant definition" do
      definitions = ParsedConstantDefinitions.new(
        root_node: parse_code("module Sales::Order::Something; end")
      )

      assert definitions.local_reference?("Sales::Order")
      assert definitions.local_reference?("Order", namespace_path: ["Sales"])
      assert definitions.local_reference?("Sales", namespace_path: [])
      refute definitions.local_reference?("More", namespace_path: ["Sales"])
    end

    test "recognizes compact nested constant assignment" do
      definitions = ParsedConstantDefinitions.new(
        root_node: parse_code('Sales::HELLO = "World"')
      )

      refute definitions.local_reference?("HELLO")
      assert definitions.local_reference?("HELLO", namespace_path: ["Sales"])
      assert definitions.local_reference?("Sales::HELLO")
      assert definitions.local_reference?("::Sales::HELLO")
    end

    test "recognizes compact nested constant definition and assignment" do
      definitions = ParsedConstantDefinitions.new(
        root_node: parse_code('module Sales::Order; Something::HELLO = "World"; end')
      )

      refute definitions.local_reference?("HELLO")
      refute definitions.local_reference?("HELLO", namespace_path: ["Sales"])
      refute definitions.local_reference?("HELLO", namespace_path: ["Sales", "Order"])
      assert definitions.local_reference?("HELLO", namespace_path: ["Sales", "Order", "Something"])
      refute definitions.local_reference?("Something::HELLO")
      refute definitions.local_reference?("Something::HELLO", namespace_path: ["Sales"])
      assert definitions.local_reference?("Something::HELLO", namespace_path: ["Sales", "Order"])
      refute definitions.local_reference?("Order::Something::HELLO")
      assert definitions.local_reference?("Order::Something::HELLO", namespace_path: ["Sales"])
      assert definitions.local_reference?("Sales::Order::Something::HELLO")
      assert definitions.local_reference?("::Sales::Order::Something::HELLO")
    end

    test "recognizes local constant reference from sub-namespace" do
      definitions = ParsedConstantDefinitions.new(
        root_node: parse_code("module Something; class Else; HELLO = 1; end; end")
      )

      assert definitions.local_reference?("HELLO", namespace_path: ["Something", "Else", "Sales"])
    end

    test "recognizes multiple constants nested in a shared ancestor module" do
      definitions = ParsedConstantDefinitions.new(
        root_node: parse_code("module Sales; class Order; end; class Thing; end; end")
      )

      assert definitions.local_reference?("Sales::Order")
      assert definitions.local_reference?("Sales::Thing")
    end

    test "doesn't count definition as reference" do
      ast = parse_code("class HelloWorld; end")

      const_node = Node.each_child(ast).find { |n| Node.constant?(n) }

      definitions = ParsedConstantDefinitions.new(
        root_node: ast
      )

      assert definitions.local_reference?(Node.constant_name(const_node))
      refute definitions.local_reference?(Node.constant_name(const_node), location: Node.name_location(const_node))
    end

    test "handles empty files" do
      ast = parse_code("# just a comment")

      definitions = ParsedConstantDefinitions.new(
        root_node: ast
      )

      refute definitions.local_reference?("Something")
    end

    test ".reference_qualifications generates all possible qualifications for a reference" do
      qualifications =
        ParsedConstantDefinitions.reference_qualifications("Order", namespace_path: ["Sales", "Internal"])

      assert_equal ["::Order", "::Sales::Order", "::Sales::Internal::Order"].sort, qualifications.sort
    end

    private

    def parse_code(string)
      ParserTestHelper.parse(string)
    end
  end
end
