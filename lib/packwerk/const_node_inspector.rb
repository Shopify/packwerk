# typed: true
# frozen_string_literal: true

require "packwerk/constant_name_inspector"

module Packwerk
  # Extracts a constant name from an AST node of type :const
  class ConstNodeInspector
    include ConstantNameInspector

    def constant_name_from_node(node, ancestors:)
      return nil unless Node.constant?(node)

      # Only process the root `const` node for namespaced constant references. For example, in the
      # reference `Spam::Eggs::Thing`, we only process the const node associated with `Spam`.
      parent = ancestors.first
      return nil if parent && Node.constant?(parent)

      if constant_in_module_or_class_definition?(node, parent: parent)
        # We're defining a class with this name, in which case the constant is implicitly fully qualified by its
        # enclosing namespace
        name = Node.parent_module_name(ancestors: ancestors)
        name ||= Node.enclosing_namespace_path(node, ancestors: ancestors).push(Node.constant_name(node)).join("::")

        "::" + name
      else
        begin
          Node.constant_name(node)
        rescue Node::TypeError
          nil
        end
      end
    end

    private

    def constant_in_module_or_class_definition?(node, parent:)
      if parent
        parent_name = Node.module_name_from_definition(parent)
        parent_name && parent_name == Node.constant_name(node)
      end
    end
  end
end
