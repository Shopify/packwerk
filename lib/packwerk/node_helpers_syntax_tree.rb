# typed: true
# frozen_string_literal: true

require "parser"
require "parser/ast/node"

module Packwerk
  # Convenience methods for working with SyntaxTree::Node nodes.
  module NodeHelpersSyntaxTree
    class TypeError < ArgumentError; end

    class << self
      extend T::Sig

      sig { params(class_or_module_node: SyntaxTree::Node).returns(String) }
      def class_or_module_name(class_or_module_node)
        case class_or_module_node
        when SyntaxTree::ClassDeclaration, SyntaxTree::ModuleDeclaration
          identifier = class_or_module_node.constant
          constant_name(identifier)
        else
          raise TypeError, "Cannot handle #{class_or_module_node.class}"
        end
      end

      sig { params(constant_node: SyntaxTree::Node).returns(String) }
      def constant_name(constant_node)
        case constant_node
        when SyntaxTree::ConstPathRef, SyntaxTree::ConstPathField
          constant_name(constant_node.parent) + "::" + constant_name(constant_node.constant)
        when SyntaxTree::VarRef, SyntaxTree::VarField
          constant_name(constant_node.value)
        when SyntaxTree::ConstRef
          constant_name(constant_node.constant)
        when SyntaxTree::Const
          constant_node.value
        when SyntaxTree::Assign
          constant_name(constant_node.target)
        when SyntaxTree::TopConstRef
          "::" + constant_name(constant_node.constant)
        else
          raise TypeError, "Cannot handle #{constant_node.class}"
        end
      end

      sig { params(node: SyntaxTree::Node).returns(T.untyped) }
      def each_child(node)
        if block_given?
          node.child_nodes.each do |child|
            yield child if child.is_a?(SyntaxTree::Node)
          end
        else
          enum_for(:each_child, node)
        end
      end

      sig { params(starting_node: SyntaxTree::Node, ancestors: T::Array[SyntaxTree::Node]).returns(T::Array[String]) }
      def enclosing_namespace_path(starting_node, ancestors:)
        ancestors.select { |n| n.is_a?(SyntaxTree::ClassDeclaration) || n.is_a?(SyntaxTree::ModuleDeclaration) }
          .each_with_object([]) do |node, namespace|
          # when evaluating `class Child < Parent`, the const node for `Parent` is a child of the class
          # node, so it'll be an ancestor, but `Parent` is not evaluated in the namespace of `Child`, so
          # we need to skip it here
          next if node.is_a?(SyntaxTree::ClassDeclaration) && parent_class(node) == starting_node

          namespace.prepend(class_or_module_name(node))
        end
      end

      sig { params(string_or_symbol_node: SyntaxTree::Node).returns(T.any(String, Symbol)) }
      def literal_value(string_or_symbol_node)
        case string_or_symbol_node
        when SyntaxTree::StringLiteral
          string_or_symbol_node.parts.map(&:value).join("")
        when SyntaxTree::SymbolLiteral
          string_or_symbol_node.value.value.to_sym
        when SyntaxTree::Label
          string_or_symbol_node.value.chop.to_sym
        else
          raise TypeError, "Cannot handle #{string_or_symbol_node.class}"
        end
      end

      sig { params(node: SyntaxTree::Node).returns(Node::Location) }
      def location(node)
        location = node.location
        Node::Location.new(location.start_line, location.start_column)
      end

      sig { params(node: SyntaxTree::Node).returns(T::Boolean) }
      def constant?(node)
        (node.is_a?(SyntaxTree::VarRef) || node.is_a?(SyntaxTree::VarField)) &&
          node.value.is_a?(SyntaxTree::Const)
      end

      sig { params(node: SyntaxTree::Node).returns(T::Boolean) }
      def constant_assignment?(node)
        node.is_a?(SyntaxTree::Assign) && constant?(node.target)
      end

      sig { params(node: SyntaxTree::Node).returns(T::Boolean) }
      def method_call?(node)
        node.is_a?(SyntaxTree::Call) || node.is_a?(SyntaxTree::FCall)
      end

      sig { params(node: SyntaxTree::Node).returns(T::Boolean) }
      def hash?(node)
        node.is_a?(SyntaxTree::HashLiteral)
      end

      sig { params(node: SyntaxTree::Node).returns(T::Boolean) }
      def string?(node)
        node.is_a?(SyntaxTree::StringLiteral)
      end

      sig { params(node: SyntaxTree::Node).returns(T::Boolean) }
      def symbol?(node)
        node.is_a?(SyntaxTree::SymbolLiteral)
      end

      sig { params(method_call_node: SyntaxTree::Node).returns(T.any(SyntaxTree::Args, SyntaxTree::ArgParen)) }
      def method_arguments(method_call_node)
        raise TypeError unless method_call?(method_call_node)

        T.cast(method_call_node, SyntaxTree::Call).arguments
      end

      sig { params(method_call_node: T.any(SyntaxTree::Call, SyntaxTree::FCall)).returns(Symbol) }
      def method_name(method_call_node)
        case method_call_node
        when SyntaxTree::Call
          method_call_node.message.value.to_sym
        when SyntaxTree::FCall
          method_call_node.value.value.to_sym
        end
      end

      sig { params(node: SyntaxTree::Node).returns(T.nilable(String)) }
      def module_name_from_definition(node)
        case node
        when SyntaxTree::ClassDeclaration, SyntaxTree::ModuleDeclaration
          class_or_module_name(node)
        when SyntaxTree::Assign
          case node.value
          when SyntaxTree::Call
            if module_creation?(node.value)
              constant_name(node.target)
            end
          when SyntaxTree::MethodAddBlock
            if module_creation?(method_call_node(node.value))
              constant_name(node.target)
            end
          end
        end
      end

      sig { params(node: SyntaxTree::Node).returns(Node::Location) }
      def name_location(node)
        puts "Deprecated: use location instead"
        location(node)
      end

      sig { params(class_node: SyntaxTree::ClassDeclaration).returns(T.nilable(SyntaxTree::Node)) }
      def parent_class(class_node)
        # (class (const nil :Foo) (const nil :Bar) (nil))
        #   "class Foo < Bar; end"
        class_node.superclass
      end

      sig { params(ancestors: T::Array[SyntaxTree::Node]).returns(String) }
      def parent_module_name(ancestors:)
        definitions = ancestors.select do |node|
          node.is_a?(SyntaxTree::ClassDeclaration) || node.is_a?(SyntaxTree::ModuleDeclaration) ||
            node.is_a?(SyntaxTree::Assign) || node.is_a?(SyntaxTree::MethodAddBlock)
        end

        names = definitions.map do |definition|
          name_part_from_definition(definition)
        end.compact

        names.empty? ? "Object" : names.reverse.join("::")
      end

      sig { params(hash_node: SyntaxTree::HashLiteral, key: Symbol).returns(T.nilable(SyntaxTree::Node)) }
      def value_from_hash(hash_node, key)
        pair = hash_pairs(hash_node).detect do |pair_node|
          literal_value(hash_pair_key(pair_node)) == key
        end
        hash_pair_value(pair) if pair
      end

      private

      sig { params(hash_pair_node: SyntaxTree::Assoc).returns(SyntaxTree::Node) }
      def hash_pair_key(hash_pair_node)
        hash_pair_node.key
      end

      sig { params(hash_pair_node: SyntaxTree::Assoc).returns(SyntaxTree::Node) }
      def hash_pair_value(hash_pair_node)
        hash_pair_node.value
      end

      sig { params(hash_node: SyntaxTree::HashLiteral).returns(T::Array[SyntaxTree::Assoc]) }
      def hash_pairs(hash_node)
        hash_node.assocs
      end

      sig { params(block_node: SyntaxTree::MethodAddBlock).returns(T.any(SyntaxTree::Call, SyntaxTree::FCall)) }
      def method_call_node(block_node)
        block_node.call
      end

      sig { params(node: SyntaxTree::Node).returns(T::Boolean) }
      def module_creation?(node)
        # "Class.new"
        # "Module.new"
        method_call?(node) &&
          dynamic_class_creation?(receiver(node)) &&
          method_name(T.cast(node, T.any(SyntaxTree::Call, SyntaxTree::FCall))) == :new
      end

      sig { params(node: T.nilable(SyntaxTree::Node)).returns(T::Boolean) }
      def dynamic_class_creation?(node)
        !!node &&
          constant?(node) &&
          ["Class", "Module"].include?(constant_name(node))
      end

      sig { params(node: SyntaxTree::MethodAddBlock).returns(T.nilable(String)) }
      def name_from_block_definition(node)
        if method_name(method_call_node(node)) == :class_eval
          receiver = receiver(node)
          constant_name(receiver) if receiver && constant?(receiver)
        end
      end

      sig { params(node: SyntaxTree::Node).returns(T.nilable(String)) }
      def name_part_from_definition(node)
        if node.is_a?(SyntaxTree::MethodAddBlock)
          name_from_block_definition(node)
        else
          module_name_from_definition(node)
        end
      end

      sig { params(method_call_or_block_node: SyntaxTree::Node).returns(T.nilable(SyntaxTree::Node)) }
      def receiver(method_call_or_block_node)
        case method_call_or_block_node
        when SyntaxTree::Call
          method_call_or_block_node.receiver
        when SyntaxTree::FCall
          nil
        when SyntaxTree::MethodAddBlock
          receiver(method_call_node(method_call_or_block_node))
        else
          raise TypeError, "Unexpected node type: #{method_call_or_block_node.class}"
        end
      end
    end
  end
end
