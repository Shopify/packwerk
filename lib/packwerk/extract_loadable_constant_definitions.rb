# typed: strict
# frozen_string_literal: true

require "ast/node"

module Packwerk
  class ExtractLoadableConstantDefinitions
    extend T::Sig

    ConstantDefinitions = T.type_alias { T::Hash[String, Node::Location] }

    sig { returns(ConstantDefinitions) }
    attr_reader :constant_definitions

    class << self
      extend T::Sig

      sig { params(node: AST::Node).returns(ConstantDefinitions) }
      def from(node)
        new(node).constant_definitions
      end
    end

    sig { params(node: AST::Node).void }
    def initialize(node)
      @constant_definitions = T.let({}, ConstantDefinitions)

      collect_leaf_definitions_from_root(node) if node
    end

    sig { params(node: AST::Node, current_namespace_path: T::Array[String]).void }
    def collect_leaf_definitions_from_root(node, current_namespace_path = [])
      if Node.constant_assignment?(node)
        # skip constant assignment, we only care about classes and modules
      elsif Node.module_name_from_definition(node)
        add_definition(Node.class_or_module_name(node), current_namespace_path, Node.name_location(node))
        current_namespace_path += Node.class_or_module_name(node).split("::")
      end

      Node.each_child(node) { |child| collect_leaf_definitions_from_root(child, current_namespace_path) }
    end

    private

    sig { params(constant_name: String, current_namespace_path: T::Array[String], location: Node::Location).void }
    def add_definition(constant_name, current_namespace_path, location)
      fully_qualified_constant = [""].concat(current_namespace_path).push(constant_name).join("::")

      # only extract the leaf constants defined in the file (e.g. "Sales::Order" but not "Sales")
      current_namespace = [""].concat(current_namespace_path).join("::")
      @constant_definitions.delete(current_namespace)

      @constant_definitions[fully_qualified_constant] = location
    end
  end
end
