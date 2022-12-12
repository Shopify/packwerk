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
      if NodeHelpers.constant_assignment?(node)
        add_definition(NodeHelpers.constant_name(node), current_namespace_path, NodeHelpers.name_location(node))
      elsif NodeHelpers.module_name_from_definition(node)
        # handle compact constant nesting (e.g. "module Sales::Order")
        tempnode = node
        while (tempnode = NodeHelpers.each_child(tempnode).find { |n| NodeHelpers.constant?(n) })
          add_definition(NodeHelpers.constant_name(tempnode), current_namespace_path,
            NodeHelpers.name_location(tempnode))
        end

        current_namespace_path += NodeHelpers.class_or_module_name(node).split("::")
      end

      NodeHelpers.each_child(node) { |child| collect_local_definitions_from_root(child, current_namespace_path) }
    end

    def add_definition(constant_name, current_namespace_path, location)
      resolved_constant = [""].concat(current_namespace_path).push(constant_name).join("::")

      @local_definitions[resolved_constant] = location
    end
  end
end
