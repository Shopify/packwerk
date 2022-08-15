# typed: true
# frozen_string_literal: true

require "ast/node"

module Packwerk
  # A collection of constant definitions parsed from an Abstract Syntax Tree (AST).
  class ParsedConstantDefinitions
    class << self
      # What fully qualified constants can this constant refer to in this context?
      def reference_qualifications(constant_name, namespace_path:)
        return [constant_name] if constant_name.start_with?("::")

        resolved_constant_name = "::#{constant_name}"

        possible_namespaces = namespace_path.each_with_object([""]) do |current, acc|
          acc << "#{acc.last}::#{current}" if acc.last && current
        end

        possible_namespaces.map { |namespace| namespace + resolved_constant_name }
      end
    end

    def initialize(root_node:)
      @local_definitions = {}

      collect_local_definitions_from_root(root_node) if root_node
    end

    def local_reference?(constant_name, location: nil, namespace_path: [])
      qualifications = self.class.reference_qualifications(constant_name, namespace_path: namespace_path)

      qualifications.any? do |name|
        @local_definitions[name] &&
          @local_definitions[name] != location
      end
    end

    private

    def collect_local_definitions_from_root(node, current_namespace_path = [])
      if Node.constant_assignment?(node)
        add_definition(Node.constant_name(node.target), current_namespace_path, Node.name_location(node.target))
      elsif Node.module_name_from_definition(node)
        namespace = add_definitions_for_module_name(node.constant, current_namespace_path)

        current_namespace_path = namespace
      end

      Node.each_child(node) { |child| collect_local_definitions_from_root(child, current_namespace_path) }
    end

    def add_definitions_for_module_name(node, current_namespace_path = [])
      case node
      when SyntaxTree::ConstPathRef
        path = add_definitions_for_module_name(node.parent, current_namespace_path)
        add_definitions_for_module_name(node.constant, path)
      when SyntaxTree::ConstRef
        add_definitions_for_module_name(node.constant, current_namespace_path)
      when SyntaxTree::VarRef
        add_definitions_for_module_name(node.value, current_namespace_path)
      when SyntaxTree::Const
        constant_name = Node.constant_name(node)
        add_definition(constant_name, current_namespace_path, Node.name_location(node))
        current_namespace_path += [constant_name]
        current_namespace_path
      end
    end

    def add_definition(constant_name, current_namespace_path, location)
      resolved_constant = [""].concat(current_namespace_path).push(constant_name).join("::")

      @local_definitions[resolved_constant] = location
    end
  end
end
