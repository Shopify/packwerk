# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class NodeHelpersSyntaxTreeTest < ActiveSupport::TestCase
    test ".class_or_module_name returns the name of a class being defined with the class keyword" do
      node = parse("class My::Class; end")
      assert_equal "My::Class", NodeHelpersSyntaxTree.class_or_module_name(node)
    end

    test ".class_or_module_name returns the name of a module being defined with the module keyword" do
      node = parse("module My::Module; end")
      assert_equal "My::Module", NodeHelpersSyntaxTree.class_or_module_name(node)
    end

    test ".constant_name returns the name of a constant being referenced" do
      node = parse("My::Constant")
      assert_equal "My::Constant", NodeHelpersSyntaxTree.constant_name(node)
    end

    test ".constant_name returns the name of a constant being assigned to" do
      node = parse("My::Constant = 42")
      assert_equal "My::Constant", NodeHelpersSyntaxTree.constant_name(node)
    end

    test ".constant_name raises a TypeError for dynamically namespaced constants" do
      node = parse("self.class::HEADERS")
      assert_raises(NodeHelpersSyntaxTree::TypeError) { NodeHelpersSyntaxTree.constant_name(node) }
    end

    test ".constant_name preserves the name of a fully-qualified constant" do
      node = parse("::My::Constant")
      assert_equal "::My::Constant", NodeHelpersSyntaxTree.constant_name(node)
    end

    test ".each_child with a block iterates over all child nodes" do
      node = parse("My::Constant = 6 * 7")
      children = []
      NodeHelpersSyntaxTree.each_child(node) do |child|
        children << child.class
      end
      assert_equal [SyntaxTree::ConstPathField, SyntaxTree::Binary], children
    end

    test ".each_child without a block returns an enumerator" do
      node = parse("My::Constant = 6 * 7")
      children = NodeHelpersSyntaxTree.each_child(node)
      assert_instance_of Enumerator, children
      assert_equal [SyntaxTree::ConstPathField, SyntaxTree::Binary], children.map(&:class)
    end

    test "#enclosing_namespace_path should return empty path for const node" do
      node = parse("Order")

      path = NodeHelpersSyntaxTree.enclosing_namespace_path(node, ancestors: [])

      assert_equal [], path
    end

    test "#enclosing_namespace_path should return correct path for simple class definition" do
      parent = parse("class Order; end")

      node = parent.bodystmt

      path = NodeHelpersSyntaxTree.enclosing_namespace_path(node, ancestors: [parent])

      assert_equal ["Order"], path
    end

    test "#enclosing_namespace_path should skip child class name when finding path for parent class" do
      grandparent = parse("module Sales; class Order < Base; end; end")
      parent = grandparent.bodystmt.statements.body.second
      node = parent.superclass

      path = NodeHelpersSyntaxTree.enclosing_namespace_path(node, ancestors: [parent, grandparent])

      assert_equal ["Sales"], path
    end

    test "#enclosing_namespace_path should return correct path for nested and compact class definition" do
      grandparent = parse("module Foo::Bar; class Sales::Order; end; end")
      parent = grandparent.bodystmt.statements.body.second
      node = parent.bodystmt

      path = NodeHelpersSyntaxTree.enclosing_namespace_path(node, ancestors: [parent, grandparent])

      assert_equal ["Foo::Bar", "Sales::Order"], path
    end

    test ".literal_value returns the value of a string node" do
      node = parse("'Hello'")
      assert_equal "Hello", NodeHelpersSyntaxTree.literal_value(node)
    end

    test ".literal_value returns the value of a symbol node" do
      node = parse(":world")
      assert_equal :world, NodeHelpersSyntaxTree.literal_value(node)
    end

    test ".location returns a source location" do
      node = parse("HELLO = 'World'")

      location = T.must(NodeHelpersSyntaxTree.location(node))

      assert_kind_of Node::Location, location
      assert_equal 1, location.line
      assert_equal 0, location.column
    end

    test ".method_arguments returns the arguments of a method call" do
      node = parse("a.b(:c, 'd', E)")
      arguments = T.cast(NodeHelpersSyntaxTree.method_arguments(node), SyntaxTree::ArgParen).arguments.parts
      assert_equal [SyntaxTree::SymbolLiteral, SyntaxTree::StringLiteral, SyntaxTree::VarRef], arguments.map(&:class)
    end

    test ".method_name returns the name of a method call" do
      node = parse("a.b(:c, 'd', E)")
      assert_equal :b, NodeHelpersSyntaxTree.method_name(node)
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
        assert_equal name, NodeHelpersSyntaxTree.module_name_from_definition(node)
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
        assert_equal name, NodeHelpersSyntaxTree.module_name_from_definition(node)
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
        assert_nil NodeHelpersSyntaxTree.module_name_from_definition(node)
      end
    end

    test ".parent_class returns the constant referring to the parent class in a class being defined with the class keyword" do
      node = parse("class B < A; end")
      assert_equal "A", T.cast(NodeHelpersSyntaxTree.parent_class(node), SyntaxTree::VarRef).value.value
    end

    test ".parent_module_name returns the name of a constant’s enclosing module" do
      grandparent = parse("module A; class B; C; end end")
      parent = grandparent.bodystmt.statements.body.second # "class B; C; end"
      assert_equal "A::B", NodeHelpersSyntaxTree.parent_module_name(ancestors: [parent, grandparent])
    end

    test ".parent_module_name returns Object if the constant has no enclosing module" do
      assert_equal "Object", NodeHelpersSyntaxTree.parent_module_name(ancestors: [])
    end

    test ".parent_module_name supports constant assignment" do
      grandparent = parse("module A; B = Class.new do C end end")
      parent = grandparent.bodystmt.statements.body.second # "B = Class.new do C end"
      assert_equal "A::B", NodeHelpersSyntaxTree.parent_module_name(ancestors: [parent, grandparent])
    end

    test ".parent_module_name supports class_eval with no receiver" do
      grandparent = parse("module A; class_eval do C; end end")
      parent = grandparent.bodystmt.statements.body.second # "class_eval do C; end"
      assert_equal "A", NodeHelpersSyntaxTree.parent_module_name(ancestors: [parent, grandparent])
    end

    test ".parent_module_name supports class_eval with an explicit receiver" do
      grandparent = parse("module A; B.class_eval do C; end end")
      parent = grandparent.bodystmt.statements.body.second # "B.class_eval do C; end"
      assert_equal "A::B", NodeHelpersSyntaxTree.parent_module_name(ancestors: [parent, grandparent])
    end

    test ".constant? can identify a constant node" do
      assert NodeHelpersSyntaxTree.constant?(parse("Oranges"))
    end

    test ".constant_assignment? can identify a constant assignment node" do
      assert NodeHelpersSyntaxTree.constant_assignment?(parse("Apples = 13"))
    end

    test ".hash? can identify a hash node" do
      assert NodeHelpersSyntaxTree.hash?(parse("{ pears: 3, bananas: 6 }"))
    end

    test ".method_call? can identify a method call node" do
      assert NodeHelpersSyntaxTree.method_call?(parse("quantity(bananas)"))
    end

    test ".string? can identify a string node" do
      assert NodeHelpersSyntaxTree.string?(parse("'cashew apple'"))
    end

    test ".symbol? can identify a symbol node" do
      assert NodeHelpersSyntaxTree.symbol?(parse(":papaya"))
    end

    test ".value_from_hash looks up the node for a key in a hash" do
      hash_node = parse("{ apples: 13, oranges: 27 }")

      value = NodeHelpersSyntaxTree.value_from_hash(hash_node, :apples)

      assert_kind_of SyntaxTree::Int, value
      assert_equal "13", T.cast(value, SyntaxTree::Int).value
    end

    test ".value_from_hash returns nil if a key isn't found in a hash" do
      hash_node = parse("{ apples: 13, oranges: 27 }")
      assert_nil NodeHelpersSyntaxTree.value_from_hash(hash_node, :pears)
    end

    private

    def parse(string)
      program = Packwerk::Parsers::SyntaxTree.new.call(io: StringIO.new(string))
      program.statements.body.first
    end
  end
end
