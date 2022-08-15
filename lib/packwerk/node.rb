# typed: true
# frozen_string_literal: true

require "parser"
require "parser/ast/node"

module Packwerk
  # Convenience methods for working with Parser::AST::Node nodes.
  module Node
    class TypeError < ArgumentError; end
    Location = Struct.new(:line, :column)

    class << self
      extend T::Sig

      def class_or_module_name(class_or_module_node)
        case class_or_module_node
        when SyntaxTree::ClassDeclaration, SyntaxTree::ModuleDeclaration
          identifier = class_or_module_node.constant
          constant_name(identifier)
        else
          raise TypeError, "Cannot handle #{class_or_module_node.class}"
        end
      end

      def constant_name(constant_node)
        case constant_node
        when SyntaxTree::ConstPathRef, SyntaxTree::ConstPathField
          constant_name(constant_node.parent) + "::" + constant_name(constant_node.constant)
        when SyntaxTree::ConstRef
          constant_name(constant_node.constant)
        when SyntaxTree::VarRef, SyntaxTree::VarField
          constant_name(constant_node.value)
        when SyntaxTree::Const
          constant_node.value
        else
          raise TypeError, "Cannot handle #{constant_node.class}"
        end
      end

      def each_child(node, &block)
        if block
          node.child_nodes.each do |child|
            if child.is_a?(SyntaxTree::Node)
              yield child
            end
          end
        else
          enum_for(:each_child, node)
        end
      end

      def enclosing_namespace_path(starting_node, ancestors:)
        ancestors.select { |n| [CLASS, MODULE].include?(type_of(n)) }
          .each_with_object([]) do |node, namespace|
          # when evaluating `class Child < Parent`, the const node for `Parent` is a child of the class
          # node, so it'll be an ancestor, but `Parent` is not evaluated in the namespace of `Child`, so
          # we need to skip it here
          next if type_of(node) == CLASS && parent_class(node) == starting_node

          namespace.prepend(class_or_module_name(node))
        end
      end

      def literal_value(string_or_symbol_node)
        case type_of(string_or_symbol_node)
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

      def constant?(node)
        node.is_a?(SyntaxTree::Const) ||
          node.is_a?(SyntaxTree::ConstRef) ||
          node.is_a?(SyntaxTree::ConstPathRef) ||
          node.is_a?(SyntaxTree::ConstPathField)
      end

      def constant_assignment?(node)
        node.is_a?(SyntaxTree::Assign) && (constant?(node.target) || constant_var_field?(node.target))
      end

      def constant_var_field?(node)
        node.is_a?(SyntaxTree::VarField) && constant?(node.value)
      end

      def class?(node)
        type_of(node) == CLASS
      end

      def method_call?(node)
        type_of(node) == METHOD_CALL
      end

      def hash?(node)
        type_of(node) == HASH
      end

      def string?(node)
        type_of(node) == STRING
      end

      def symbol?(node)
        type_of(node) == SYMBOL
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
        case node
        when SyntaxTree::ClassDeclaration, SyntaxTree::ModuleDeclaration
          # "class My::Class; end"
          # "module My::Module; end"
          class_or_module_name(node)
        when CONSTANT_ASSIGNMENT
          # "My::Class = ..."
          # "My::Module = ..."
          rvalue = node.children.last

          case type_of(rvalue)
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

        Location.new(location.start_line, location.start_column)
      end

      def parent_class(class_node)
        raise TypeError unless type_of(class_node) == CLASS

        # (class (const nil :Foo) (const nil :Bar) (nil))
        #   "class Foo < Bar; end"
        class_node.children[1]
      end

      sig { params(ancestors: T::Array[SyntaxTree::Node]).returns(String) }
      def parent_module_name(ancestors:)
        definitions = ancestors
          .select { |n| [CLASS, MODULE, CONSTANT_ASSIGNMENT, BLOCK].include?(type_of(n)) }

        names = definitions.map do |definition|
          name_part_from_definition(definition)
        end.compact

        names.empty? ? "Object" : names.reverse.join("::")
      end

      def value_from_hash(hash_node, key)
        raise TypeError unless hash?(hash_node)

        pair = hash_pairs(hash_node).detect { |pair_node| literal_value(hash_pair_key(pair_node)) == key }
        hash_pair_value(pair) if pair
      end

      private

      BLOCK = :block
      CLASS = :class
      CONSTANT = :const
      CONSTANT_ASSIGNMENT = :casgn
      CONSTANT_ROOT_NAMESPACE = :cbase
      HASH = :hash
      HASH_PAIR = :pair
      METHOD_CALL = :send
      MODULE = :module
      SELF = :self
      STRING = :str
      SYMBOL = :sym

      private_constant(
        :BLOCK, :CLASS, :CONSTANT, :CONSTANT_ASSIGNMENT, :CONSTANT_ROOT_NAMESPACE, :HASH, :HASH_PAIR, :METHOD_CALL,
        :MODULE, :SELF, :STRING, :SYMBOL,
      )

      def type_of(node)
        node.type
      end

      def hash_pair_key(hash_pair_node)
        raise TypeError unless type_of(hash_pair_node) == HASH_PAIR

        # (pair (int 1) (int 2))
        #   "1 => 2"
        # (pair (sym :answer) (int 42))
        #   "answer: 42"
        hash_pair_node.children[0]
      end

      def hash_pair_value(hash_pair_node)
        raise TypeError unless type_of(hash_pair_node) == HASH_PAIR

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
        hash_node.children.select { |n| type_of(n) == HASH_PAIR }
      end

      def method_call_node(block_node)
        raise TypeError unless type_of(block_node) == BLOCK

        # (block (send (lvar :foo) :bar) (args) (int 42))
        #   "foo.bar do 42 end"
        block_node.children[0]
      end

      def module_creation?(node)
        # "Class.new"
        # "Module.new"
        method_call?(node) &&
          receiver(node) &&
          constant?(receiver(node)) &&
          ["Class", "Module"].include?(constant_name(receiver(node))) &&
          method_name(node) == :new
      end

      def name_from_block_definition(node)
        if method_name(method_call_node(node)) == :class_eval
          receiver = receiver(node)
          constant_name(receiver) if receiver && constant?(receiver)
        end
      end

      def name_part_from_definition(node)
        case type_of(node)
        when CLASS, MODULE, CONSTANT_ASSIGNMENT
          module_name_from_definition(node)
        when BLOCK
          name_from_block_definition(node)
        end
      end

      def receiver(method_call_or_block_node)
        case type_of(method_call_or_block_node)
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
