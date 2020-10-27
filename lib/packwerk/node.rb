# typed: true
# frozen_string_literal: true

require "parser/ast/node"

module Packwerk
  module Node
    BLOCK = :block
    CLASS = :class
    CONSTANT = :const
    CONSTANT_ASSIGNMENT = :casgn
    CONSTANT_ROOT_NAMESPACE = :cbase
    HASH = :hash
    HASH_PAIR = :pair
    METHOD_CALL = :send
    MODULE = :module
    STRING = :str
    SYMBOL = :sym

    class TypeError < ArgumentError; end
    Location = Struct.new(:line, :column)

    class << self
      def class_or_module_name(class_or_module_node)
        case type(class_or_module_node)
        when CLASS, MODULE
          # (class (const nil :Foo) (const nil :Bar) (nil))
          #   "class Foo < Bar; end"
          # (module (const nil :Foo) (nil))
          #   "module Foo; end"
          identifier = class_or_module_node.children[0]
          constant_name(identifier)
        else
          raise TypeError
        end
      end

      def constant_name(constant_node)
        case type(constant_node)
        when CONSTANT_ROOT_NAMESPACE
          ""
        when CONSTANT, CONSTANT_ASSIGNMENT
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
          namespace, name = constant_node.children
          if namespace
            [constant_name(namespace), name].join("::")
          else
            name.to_s
          end
        else
          raise TypeError
        end
      end

      def each_child(node)
        if block_given?
          node.children.each do |child|
            yield child if child.is_a?(Parser::AST::Node)
          end
        else
          enum_for(:each_child, node)
        end
      end

      def enclosing_namespace_path(starting_node, ancestors:)
        ancestors.select { |n| [CLASS, MODULE].include?(type(n)) }
          .each_with_object([]) do |node, namespace|
          # when evaluating `class Child < Parent`, the const node for `Parent` is a child of the class
          # node, so it'll be an ancestor, but `Parent` is not evaluated in the namespace of `Child`, so
          # we need to skip it here
          next if type(node) == CLASS && parent_class(node) == starting_node

          namespace.prepend(class_or_module_name(node))
        end
      end

      def literal_value(string_or_symbol_node)
        case type(string_or_symbol_node)
        when STRING, SYMBOL
          # (str "foo")
          #   "'foo'"
          # (sym :foo)
          #   ":foo"
          string_or_symbol_node.children[0]
        else
          raise TypeError
        end
      end

      def location(node)
        location = node.location
        Location.new(location.line, location.column)
      end

      def method_call?(node)
        type(node) == METHOD_CALL
      end

      def hash?(node)
        type(node) == HASH
      end

      def string?(node)
        type(node) == STRING
      end

      def symbol?(node)
        type(node) == SYMBOL
      end

      def method_arguments(method_call_node)
        raise TypeError unless method_call?(method_call_node)

        # (send (lvar :foo) :bar (int 1))
        #   "foo.bar(1)"
        method_call_node.children.slice(2..-1)
      end

      def method_name(method_call_node)
        raise TypeError unless method_call?(method_call_node)

        # (send (lvar :foo) :bar (int 1))
        #   "foo.bar(1)"
        method_call_node.children[1]
      end

      def module_name_from_definition(node)
        case type(node)
        when CLASS, MODULE
          # "class My::Class; end"
          # "module My::Module; end"
          class_or_module_name(node)
        when CONSTANT_ASSIGNMENT
          # "My::Class = ..."
          # "My::Module = ..."
          rvalue = node.children.last

          case type(rvalue)
          when METHOD_CALL
            # "Class.new"
            # "Module.new"
            constant_name(node) if module_creation?(rvalue)
          when BLOCK
            # "Class.new do end"
            # "Module.new do end"
            constant_name(node) if module_creation?(method_call_node(rvalue))
          end
        end
      end

      def name_location(node)
        location = node.location

        if location.respond_to?(:name)
          name = location.name
          Location.new(name.line, name.column)
        end
      end

      def parent_class(class_node)
        raise TypeError unless type(class_node) == CLASS

        # (class (const nil :Foo) (const nil :Bar) (nil))
        #   "class Foo < Bar; end"
        class_node.children[1]
      end

      def parent_module_name(ancestors:)
        definitions = ancestors
          .select { |n| [CLASS, MODULE, CONSTANT_ASSIGNMENT, BLOCK].include?(type(n)) }

        names = definitions.map do |definition|
          name_part_from_definition(definition)
        end.compact

        names.empty? ? "Object" : names.reverse.join("::")
      end

      def type(node)
        node.type
      end

      def value_from_hash(hash_node, key)
        raise TypeError unless hash?(hash_node)
        pair = hash_pairs(hash_node).detect { |pair_node| literal_value(hash_pair_key(pair_node)) == key }
        hash_pair_value(pair) if pair
      end

      private

      def hash_pair_key(hash_pair_node)
        raise TypeError unless type(hash_pair_node) == HASH_PAIR

        # (pair (int 1) (int 2))
        #   "1 => 2"
        # (pair (sym :answer) (int 42))
        #   "answer: 42"
        hash_pair_node.children[0]
      end

      def hash_pair_value(hash_pair_node)
        raise TypeError unless type(hash_pair_node) == HASH_PAIR

        # (pair (int 1) (int 2))
        #   "1 => 2"
        # (pair (sym :answer) (int 42))
        #   "answer: 42"
        hash_pair_node.children[1]
      end

      def hash_pairs(hash_node)
        raise TypeError unless hash?(hash_node)

        # (hash (pair (int 1) (int 2)) (pair (int 3) (int 4)))
        #   "{1 => 2, 3 => 4}"
        hash_node.children.select { |n| type(n) == HASH_PAIR }
      end

      def method_call_node(block_node)
        raise TypeError unless type(block_node) == BLOCK

        # (block (send (lvar :foo) :bar) (args) (int 42))
        #   "foo.bar do 42 end"
        block_node.children[0]
      end

      def module_creation?(node)
        # "Class.new"
        # "Module.new"
        method_call?(node) &&
          type(receiver(node)) == CONSTANT &&
          ["Class", "Module"].include?(constant_name(receiver(node))) &&
          method_name(node) == :new
      end

      def name_from_block_definition(node)
        if method_name(method_call_node(node)) == :class_eval
          receiver = receiver(node)
          constant_name(receiver) if receiver && type(receiver) == CONSTANT
        end
      end

      def name_part_from_definition(node)
        case type(node)
        when CLASS, MODULE, CONSTANT_ASSIGNMENT
          module_name_from_definition(node)
        when BLOCK
          name_from_block_definition(node)
        end
      end

      def receiver(method_call_or_block_node)
        case type(method_call_or_block_node)
        when METHOD_CALL
          method_call_or_block_node.children[0]
        when BLOCK
          receiver(method_call_node(method_call_or_block_node))
        else
          raise TypeError
        end
      end
    end
  end
end
