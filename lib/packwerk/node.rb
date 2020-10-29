# typed: true
# frozen_string_literal: true

require "parser/ast/node"
require "packwerk/ancestors"
require "packwerk/node/node_factory"

module Packwerk
  class Node
    class TypeError < ArgumentError; end
    Location = Struct.new(:line, :column)

    attr_reader :node

    def initialize(node)
      @node = node
    end

    def ==(other)
      other.node == node
    end

    def children
      node.children.map { |n| NodeFactory.for(n) }
    end

    def each_child
      if block_given?
        node.children.each do |child|
          yield NodeFactory.for(child) if child.is_a?(Parser::AST::Node)
        end
      else
        enum_for(:each_child)
      end
    end

    def location
      Location.new(node.location.line, node.location.column)
    end

    def name_location
      location = node.location

      if location.respond_to?(:name)
        name = location.name
        Location.new(name.line, name.column)
      end
    end

    %i[
      module_creation? symbol? string? hash? module? method_call? class? constant_root_namespace? constant_assignment?
      constant?
    ].each { |name| define_method(name) { false } }

    %i[
      parent_class value_from_hash hash_pair_key hash_pair_value name_part_from_definition receiver
      module_name_from_definition class_or_module_name literal_value hash_pairs method_call_node method_arguments
      method_name
    ].each { |name| define_method(name) { raise TypeError } }
  end

  class BlockNode < Node
    TYPE = :block

    def block?
      true
    end

    def receiver
      method_call_node.receiver
    end

    def name_part_from_definition
      if class_eval? && receiver&.constant?
        receiver.constant_name
      end
    end

    def method_call_node
      # (block (send (lvar :foo) :bar) (args) (int 42))
      #   "foo.bar do 42 end"
      node.children[0]
    end

    private

    def class_eval?
      method_call_node.method_name == :class_eval
    end
  end

  class ClassNode < Node
    TYPE = :class

    def class?
      true
    end

    def class_or_module_name
      # (class (const nil :Foo) (const nil :Bar) (nil))
      #   "class Foo < Bar; end"
      # (module (const nil :Foo) (nil))
      #   "module Foo; end"
      children[0].constant_name
    end

    def name_part_from_definition
      module_name_from_definition
    end

    def module_name_from_definition
      # "class My::Class; end"
      # "module My::Module; end"
      class_or_module_name
    end

    def parent_class
      # (class (const nil :Foo) (const nil :Bar) (nil))
      #   "class Foo < Bar; end"
      children[1]
    end
  end

  class ConstantNode < Node
    TYPE = :const

    def constant?
      true
    end

    def constant_name
      # (const nil :Foo)
      #   "Foo"
      # (const (cbase) :Foo)
      #   "::Foo"
      # (const (lvar :a) :Foo)
      #   "a::Foo"
      # (casgn nil :Foo (int 1))
      #   "Foo = 1"
      # (casgn (cbase) :Foo (int 1))
      #   "::Foo = 1"
      # (casgn (lvar :a) :Foo (int 1))
      #   "a::Foo = 1"
      namespace, name = node.children
      if namespace
        namespace = NodeFactory.for(namespace)
        [namespace.constant_name, name].join("::")
      else
        name.to_s
      end
    end
  end

  class ConstantAssignmentNode < Node
    TYPE = :casgn

    def constant_assignment?
      true
    end

    def name_part_from_definition
      module_name_from_definition
    end

    def module_name_from_definition
      # "My::Class = ..."
      # "My::Module = ..."
      rvalue = children.last

      if rvalue.method_call?
        # "Class.new"
        # "Module.new"
        node.constant_name if rvalue.module_creation?
      elsif rvalue.block?
        # "Class.new do end"
        # "Module.new do end"
        node.constant_name if rvalue.method_call_node.module_creation?
      end
    end

    def constant_name
      # (const nil :Foo)
      #   "Foo"
      # (const (cbase) :Foo)
      #   "::Foo"
      # (const (lvar :a) :Foo)
      #   "a::Foo"
      # (casgn nil :Foo (int 1))
      #   "Foo = 1"
      # (casgn (cbase) :Foo (int 1))
      #   "::Foo = 1"
      # (casgn (lvar :a) :Foo (int 1))
      #   "a::Foo = 1"
      namespace, name = node.children
      if namespace
        [namespace.constant_name, name].join("::")
      else
        name.to_s
      end
    end
  end

  class ConstantRootNamespaceNode < Node
    TYPE = :cbase

    def constant_root_namespace?
      true
    end

    def constant_name
      ""
    end
  end

  class HashNode < Node
    TYPE = :hash

    def hash?
      true
    end

    def value_from_hash(key)
      hash_pairs
        .detect { |pair_node| literal_value(hash_pair_key(pair_node)) == key }
        &.hash_pair_value
    end

    private

    def hash_pairs
      # (hash (pair (int 1) (int 2)) (pair (int 3) (int 4)))
      #   "{1 => 2, 3 => 4}"
      children.select(&:hash_pair?)
    end
  end

  class HashPairNode < Node
    TYPE = :pair

    def hash_pair?
      true
    end

    def hash_pair_key
      # (pair (int 1) (int 2))
      #   "1 => 2"
      # (pair (sym :answer) (int 42))
      #   "answer: 42"
      children[0]
    end

    def hash_pair_value
      # (pair (int 1) (int 2))
      #   "1 => 2"
      # (pair (sym :answer) (int 42))
      #   "answer: 42"
      children[1]
    end
  end

  class MethodCallNode < Node
    TYPE = :send

    def method_call?
      true
    end

    def module_creation?
      # "Class.new"
      # "Module.new"
      receiver.constant? && receiver_is_module_or_class? && method_call_new?
    end

    def method_arguments
      # (send (lvar :foo) :bar (int 1))
      #   "foo.bar(1)"
      node.children.slice(2..-1)
    end

    def method_name
      # (send (lvar :foo) :bar (int 1))
      #   "foo.bar(1)"
      node.children[1]
    end

    def receiver
      node.children[0]
    end

    private

    def receiver_is_module_or_class?
      ["Class", "Module"].include?(receiver.constant_name)
    end

    def method_call_new?
      node.method_name == :new
    end
  end

  class ModuleNode < Node
    TYPE = :module

    def module?
      true
    end

    def name_part_from_definition
      module_name_from_definition
    end

    def class_or_module_name
      # (class (const nil :Foo) (const nil :Bar) (nil))
      #   "class Foo < Bar; end"
      # (module (const nil :Foo) (nil))
      #   "module Foo; end"
      children[0].constant_name
    end
  end

  class StringNode < Node
    TYPE = :str

    def string?
      true
    end

    def literal_value
      # (str "foo")
      #   "'foo'"
      # (sym :foo)
      #   ":foo"
      node.children[0]
    end
  end

  class SymbolNode < Node
    TYPE = :sym

    def symbol?
      true
    end

    def literal_value
      # (str "foo")
      #   "'foo'"
      # (sym :foo)
      #   ":foo"
      node.children[0]
    end
  end
end
