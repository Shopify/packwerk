# typed: true
# frozen_string_literal: true

module Packwerk
  module Node
    BLOCK = :ITER
    CLASS = :CLASS
    CONSTANT = :CONST
    CONSTANT_ASSIGNMENT = :CDECL
    CONSTANT_ROOT_NAMESPACE = :cbase
    HASH = :HASH
    METHOD_CALL = :FCALL
    MODULE = :MODULE
    SCOPE = :SCOPE
    STRING = :STR
    SYMBOL = :LIT # FIXME: could contain a string or a symbol or a number etc

    class TypeError < ArgumentError; end
    Location = Struct.new(:line, :column)

    class << self
      extend T::Sig

      def class_or_module_name(class_or_module_node)
        case type_of(class_or_module_node)
        when CLASS, MODULE
          # (class (const nil :Foo) (const nil :Bar) (nil))
          #   "class Foo < Bar; end"
          # (module (const nil :Foo) (nil))
          #   "module Foo; end"
          identifier = enter_scope(class_or_module_node).children[0]
          constant_name(identifier)
        else
          raise TypeError
        end
      end

      def constant_name(constant_node)
        constant_node = enter_scope(constant_node)

        case type(constant_node)
        when CONSTANT_ASSIGNMENT
          identifier = constant_node.children[0]

          case identifier
          when RubyVM::AbstractSyntaxTree::Node
            constant_name(identifier)
          else
            identifier.to_s
          end
        when :COLON2
          namespace, name = constant_node.children

          if namespace
            [constant_name(namespace), name].join("::")
          else
            name.to_s
          end
        when :COLON3
          "::" + constant_node.children[0].to_s
        when CONSTANT
          constant_node.children[0].to_s
        else
          raise TypeError
        end
      end

      def each_child(node)
        if block_given?
          enter_scope(node).children.each do |child|
            if child.is_a?(RubyVM::AbstractSyntaxTree::Node)
              child = enter_scope(child)
              yield child if child&.is_a?(RubyVM::AbstractSyntaxTree::Node)
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

          next if type(node) == CLASS && !(parent = parent_class(node)).nil? &&
            same_content?(parent, starting_node, check_location: true)

          namespace.prepend(class_or_module_name(node))
        end
      end

      def literal_value(string_or_symbol_node)
        string_or_symbol_node = enter_scope(string_or_symbol_node)

        case type(string_or_symbol_node)
        when STRING, SYMBOL
          # (STR "foo")
          #   "'foo'"
          # (LIT :foo)
          #   ":foo"
          string_or_symbol_node.children[0]
        else
          raise TypeError
        end
      end

      def location(node)
        Location.new(node.first_lineno, node.first_column)
      end

      def constant?(node)
        type_of(node) == CONSTANT
      end

      def constant_assignment?(node)
        type_of(node) == CONSTANT_ASSIGNMENT
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
        method_call_node = enter_scope(method_call_node)

        case type(method_call_node)
        when :CALL # FIXME
          method_call_node.children[2].children.slice(0..-2)
        when :FCALL # FIXME
          method_call_node.children[1].children.slice(0..-2)
        end
      end

      def method_name(method_call_node)
        method_call_node = enter_scope(method_call_node)

        case type(method_call_node)
        when :CALL # FIXME
          method_call_node.children[1]
        when :FCALL, :VCALL # FIXME
          method_call_node.children[0]
        else
          raise TypeError
        end
      end

      def module_name_from_definition(node)
        node = enter_scope(node)

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
          when :CALL
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
        node = enter_scope(node)

        case type(node)
        when CONSTANT, CONSTANT_ASSIGNMENT, :COLON2, :COLON3
          name = node
          Location.new(name.first_lineno, name.first_column)
        end
      end

      def parent_class(class_node)
        raise TypeError unless type_of(class_node) == CLASS

        enter_scope(class_node).children[1]
      end

      sig { params(ancestors: T::Array[AST::Node]).returns(String) }
      def parent_module_name(ancestors:)
        definitions = ancestors
          .select { |n| [CLASS, MODULE, CONSTANT_ASSIGNMENT, BLOCK].include?(type_of(n)) }

        names = definitions.map do |definition|
          name_part_from_definition(definition)
        end.compact

        names.empty? ? "Object" : names.reverse.join("::")
      end

      def same_content?(a, b, check_location: false)
        return false unless
          !check_location ||
          [:first_lineno, :first_column, :last_lineno, :last_column].all? do |attr|
            a.send(attr) == b.send(attr)
          end
        return false unless a.type == b.type

        a_children = a.children
        b_children = b.children
        return false unless a_children.length == b_children.length

        a_children.zip(b_children).all? do |c, d|
          return false unless c.class == d.class

          if c.is_a?(RubyVM::AbstractSyntaxTree::Node)
            same_content?(c, d, check_location: check_location)
          else
            c == d
          end
        end
      end

      def type(node)
        enter_scope(node).type
      end

      def value_from_hash(hash_node, key)
        raise TypeError unless hash?(hash_node)
        pair = hash_pairs(hash_node).detect { |pair_node| literal_value(hash_pair_key(pair_node)) == key }
        hash_pair_value(pair) if pair
      end

      private

      def enter_scope(node)
        case node.type
        when SCOPE
          body = node.children[2]
          body if body
        else
          node
        end
      end

      def hash_pair_key(hash_pair)
        hash_pair[0]
      end

      def hash_pair_value(hash_pair)
        hash_pair[1]
      end

      def hash_pairs(hash_node)
        raise TypeError unless hash?(hash_node)

        # (HASH (ARRAY (LIT 1) (LIT 2) (LIT 3) (LIT 4) nil))
        #   "{1 => 2, 3 => 4}"
        enter_scope(hash_node).children[0].children.slice(0..-2).each_slice(2)
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
        type(node) == :CALL && # FIXME
          type(receiver(node)) == CONSTANT &&
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
        case type(method_call_or_block_node)
        when :CALL # FIXME
          method_call_or_block_node.children[0]
        when :FCALL # FIXME
          nil
        when BLOCK
          receiver(method_call_node(method_call_or_block_node))
        else
          raise TypeError
        end
      end
    end
  end
end
