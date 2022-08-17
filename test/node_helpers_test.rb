# typed: true
# frozen_string_literal: true

require "test_helper"
require "parser_test_helper"

require "parser"

module Packwerk
  class NodeHelpersTest < ActiveSupport::TestCase
    test ".class_or_module_name returns the name of a class being defined with the class keyword" do
      node = parse("class My::Class; end")
      assert_equal "My::Class", NodeHelpers.class_or_module_name(node)
    end

    test ".class_or_module_name returns the name of a module being defined with the module keyword" do
      node = parse("module My::Module; end")
      assert_equal "My::Module", NodeHelpers.class_or_module_name(node)
    end

    test ".constant_name returns the name of a constant being referenced" do
      node = parse("My::Constant")
      assert_equal "My::Constant", NodeHelpers.constant_name(node)
    end

    test ".constant_name returns the name of a constant being assigned to" do
      node = parse("My::Constant = 42")
      assert_equal "My::Constant", NodeHelpers.constant_name(node)
    end

    test ".constant_name raises a TypeError for dynamically namespaced constants" do
      node = parse("self.class::HEADERS")
      assert_raises(NodeHelpers::TypeError) { NodeHelpers.constant_name(node) }
    end

    test ".constant_name preserves the name of a fully-qualified constant" do
      node = parse("::My::Constant")
      assert_equal "::My::Constant", NodeHelpers.constant_name(node)
    end

    test ".each_child with a block iterates over all child nodes" do
      node = parse("My::Constant = 6 * 7")
      children = []
      NodeHelpers.each_child(node) do |child|
        children << child
      end
      assert_equal [parse("My"), parse("6 * 7")], children
    end

    test ".each_child without a block returns an enumerator" do
      node = parse("My::Constant = 6 * 7")
      children = NodeHelpers.each_child(node)
      assert_instance_of Enumerator, children
      assert_equal [parse("My"), parse("6 * 7")], children.entries
    end

    test "#enclosing_namespace_path should return empty path for const node" do
      node = parse("Order")

      path = NodeHelpers.enclosing_namespace_path(node, ancestors: [])

      assert_equal [], path
    end

    test "#enclosing_namespace_path should return correct path for simple class definition" do
      parent = parse("class Order; end")
      node = NodeHelpers.each_child(parent).entries[0]

      path = NodeHelpers.enclosing_namespace_path(node, ancestors: [parent])

      assert_equal ["Order"], path
    end

    test "#enclosing_namespace_path should skip child class name when finding path for parent class" do
      grandparent = parse("module Sales; class Order < Base; end; end")
      parent = NodeHelpers.each_child(grandparent).entries[1] # module node; second child is the body of the module
      node = NodeHelpers.each_child(parent).entries[1] # class node; second child is parent

      path = NodeHelpers.enclosing_namespace_path(node, ancestors: [parent, grandparent])

      assert_equal ["Sales"], path
    end

    test "#enclosing_namespace_path should return correct path for nested and compact class definition" do
      grandparent = parse("module Foo::Bar; class Sales::Order; end; end")
      parent = NodeHelpers.each_child(grandparent).entries[1] # module node; second child is the body of the module
      node = NodeHelpers.each_child(parent).entries[0] # class node; first child is constant

      path = NodeHelpers.enclosing_namespace_path(node, ancestors: [parent, grandparent])

      assert_equal ["Foo::Bar", "Sales::Order"], path
    end

    test ".literal_value returns the value of a string node" do
      node = parse("'Hello'")
      assert_equal "Hello", NodeHelpers.literal_value(node)
    end

    test ".literal_value returns the value of a symbol node" do
      node = parse(":world")
      assert_equal :world, NodeHelpers.literal_value(node)
    end

    test ".location returns a source location" do
      node = parse("HELLO = 'World'")
      assert_kind_of Node::Location, NodeHelpers.location(node)
    end

    test ".method_arguments returns the arguments of a method call" do
      node = parse("a.b(:c, 'd', E)")
      assert_equal [parse(":c"), parse("'d'"), parse("E")], NodeHelpers.method_arguments(node)
    end

    test ".method_name returns the name of a method call" do
      node = parse("a.b(:c, 'd', E)")
      assert_equal :b, NodeHelpers.method_name(node)
    end

    test ".module_name_from_definition returns the name of the class being defined" do
      [
        ["class MyClass; end", "MyClass"],
        ["class ::MyClass; end", "::MyClass"],
        ["class My::Class; end", "My::Class"],
        ["My::Class = Class.new", "My::Class"],
        ["My::Class = Class.new do end", "My::Class"],
      ].each do |class_definition, name|
        node = parse(class_definition)
        assert_equal name, NodeHelpers.module_name_from_definition(node)
      end
    end

    test ".module_name_from_definition returns the name of the module being defined" do
      [
        ["module MyModule; end", "MyModule"],
        ["module ::MyModule; end", "::MyModule"],
        ["module My::Module; end", "My::Module"],
        ["My::Module = Module.new", "My::Module"],
        ["My::Module = Module.new do end", "My::Module"],
      ].each do |module_definition, name|
        node = parse(module_definition)
        assert_equal name, NodeHelpers.module_name_from_definition(node)
      end
    end

    test ".module_name_from_definition returns nil if no class or module is being defined" do
      [
        "'Hello'",
        "MyConstant",
        "MyObject = Object.new",
        "MyFile = File.new do end",
        "-> x { x * 2 }",
        "Class.new",
        "Class.new do end",
        "MyConstant = -> {}",
      ].each do |module_definition|
        node = parse(module_definition)
        assert_nil NodeHelpers.module_name_from_definition(node)
      end
    end

    test ".name_location returns a source location for a constant" do
      node = parse("HELLO")
      assert_kind_of Node::Location, NodeHelpers.name_location(node)
    end

    test ".name_location returns a source location for a constant assignment" do
      node = parse("HELLO = 'World'")
      assert_kind_of Node::Location, NodeHelpers.name_location(node)
    end

    test ".name_location returns nil for a method call" do
      node = parse("has_many :hellos")
      assert_nil NodeHelpers.name_location(node)
    end

    test ".parent_class returns the constant referring to the parent class in a class being defined with the class keyword" do
      node = parse("class B < A; end")
      assert_equal parse("A"), NodeHelpers.parent_class(node)
    end

    test ".parent_module_name returns the name of a constant’s enclosing module" do
      grandparent = parse("module A; class B; C; end end")
      parent = NodeHelpers.each_child(grandparent).entries[1] # "class B; C; end"
      assert_equal "A::B", NodeHelpers.parent_module_name(ancestors: [parent, grandparent])
    end

    test ".parent_module_name returns Object if the constant has no enclosing module" do
      assert_equal "Object", NodeHelpers.parent_module_name(ancestors: [])
    end

    test ".parent_module_name supports constant assignment" do
      grandparent = parse("module A; B = Class.new do C end end")
      parent = NodeHelpers.each_child(grandparent).entries[1] # "B = Class.new do C end"
      assert_equal "A::B", NodeHelpers.parent_module_name(ancestors: [parent, grandparent])
    end

    test ".parent_module_name supports class_eval with no receiver" do
      grandparent = parse("module A; class_eval do C; end end")
      parent = NodeHelpers.each_child(grandparent).entries[1] # "class_eval do C; end"
      assert_equal "A", NodeHelpers.parent_module_name(ancestors: [parent, grandparent])
    end

    test ".parent_module_name supports class_eval with an explicit receiver" do
      grandparent = parse("module A; B.class_eval do C; end end")
      parent = NodeHelpers.each_child(grandparent).entries[1] # "B.class_eval do C; end"
      assert_equal "A::B", NodeHelpers.parent_module_name(ancestors: [parent, grandparent])
    end

    test ".class? can identify a class node" do
      assert NodeHelpers.class?(parse("class Fruit; end"))
    end

    test ".constant? can identify a constant node" do
      assert NodeHelpers.constant?(parse("Oranges"))
    end

    test ".constant_assignment? can identify a constant assignment node" do
      assert NodeHelpers.constant_assignment?(parse("Apples = 13"))
    end

    test ".hash? can identify a hash node" do
      assert NodeHelpers.hash?(parse("{ pears: 3, bananas: 6 }"))
    end

    test ".method_call? can identify a method call node" do
      assert NodeHelpers.method_call?(parse("quantity(bananas)"))
    end

    test ".string? can identify a string node" do
      assert NodeHelpers.string?(parse("'cashew apple'"))
    end

    test ".symbol? can identify a symbol node" do
      assert NodeHelpers.symbol?(parse(":papaya"))
    end

    test ".value_from_hash looks up the node for a key in a hash" do
      hash_node = parse("{ apples: 13, oranges: 27 }")
      assert_equal parse("13"), NodeHelpers.value_from_hash(hash_node, :apples)
    end

    test ".value_from_hash returns nil if a key isn't found in a hash" do
      hash_node = parse("{ apples: 13, oranges: 27 }")
      assert_nil NodeHelpers.value_from_hash(hash_node, :pears)
    end

    private

    def parse(string)
      ParserTestHelper.parse(string)
    end
  end
end
