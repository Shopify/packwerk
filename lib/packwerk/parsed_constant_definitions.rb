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
      if node.constant_assignment?
        add_definition(node.constant_name, current_namespace_path, node.name_location)
      elsif node.module_name_from_definition
        # handle compact constant nesting (e.g. "module Sales::Order")
        tempnode = node
        while (tempnode = tempnode.each_child.find(&:constant?))
          add_definition(tempnode.constant_name, current_namespace_path, tempnode.name_location)
        end

        current_namespace_path += node.class_or_module_name.split("::")
      end

      node.each_child { |child| collect_local_definitions_from_root(child, current_namespace_path) }
    end

    def add_definition(constant_name, current_namespace_path, location)
      fully_qualified_constant = [""].concat(current_namespace_path).push(constant_name).join("::")

      @local_definitions[fully_qualified_constant] = location
    end
  end
end
