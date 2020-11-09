# typed: true
# frozen_string_literal: true

require "ast/node"

require "packwerk/node"

module Packwerk
  class ParsedConstantDefinitions
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

    # What fully qualified constants can this constant refer to in this context?
    def self.reference_qualifications(constant_name, namespace_path:)
      return [constant_name] if constant_name.start_with?("::")

      fully_qualified_constant_name = "::#{constant_name}"

      possible_namespaces = namespace_path.reduce([""]) do |acc, current|
        acc << acc.last + "::" + current
      end

      possible_namespaces.map { |namespace| namespace + fully_qualified_constant_name }
    end

    private

    def collect_local_definitions_from_root(node, current_namespace_path = [])
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

      Node.each_child(node) { |child| collect_local_definitions_from_root(child, current_namespace_path) }
    end

    def add_definition(constant_name, current_namespace_path, location)
      fully_qualified_constant = [""].concat(current_namespace_path).push(constant_name).join("::")

      @local_definitions[fully_qualified_constant] = location
    end
  end
end
