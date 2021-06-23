# typed: false
# frozen_string_literal: true

require "ast/node"

module Packwerk
  module Classic
    class ExtractConstantDefinitions
      attr_reader :constant_definitions

      def initialize(root_node:)
        @constant_definitions = {}

        collect_leaf_definitions_from_root(root_node) if root_node
      end

      def collect_leaf_definitions_from_root(node, current_namespace_path = [])
        if Node.constant_assignment?(node)
          add_definition(Node.constant_name(node), current_namespace_path, Node.name_location(node))
        elsif Node.module_name_from_definition(node)
          # handle compact constant nesting (e.g. "module Sales::Order")
          tempnode = node
          while (tempnode = Node.each_child(tempnode).find { |n| Node.constant?(n) })
            add_definition(Node.constant_name(tempnode), current_namespace_path, Node.name_location(tempnode))
          end

          current_namespace_path += Node.class_or_module_name(node).split("::")
        end

        Node.each_child(node) { |child| collect_leaf_definitions_from_root(child, current_namespace_path) }
      end

      private

      def add_definition(constant_name, current_namespace_path, location)
        fully_qualified_constant = [""].concat(current_namespace_path).push(constant_name).join("::")

        # only extract the leaf constants defined in the file (e.g. "Sales::Order" but not "Sales")
        current_namespace = [""].concat(current_namespace_path).join("::")
        @constant_definitions.delete(current_namespace)

        @constant_definitions[fully_qualified_constant] = location
      end
    end
  end
end
