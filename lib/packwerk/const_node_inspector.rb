# typed: strict
# frozen_string_literal: true

module Packwerk
  # Extracts a constant name from an AST node of type :const
  class ConstNodeInspector
    include ConstantNameInspector

    # @override
    #: (AST::Node node, ancestors: Array[AST::Node], relative_file: String) -> String?
    def constant_name_from_node(node, ancestors:, relative_file:)
      return nil unless NodeHelpers.constant?(node)

      parent = ancestors.first

      # Only process the root `const` node for namespaced constant references. For example, in the
      # reference `Spam::Eggs::Thing`, we only process the const node associated with `Spam`.
      return nil unless root_constant?(parent)

      if parent && constant_in_module_or_class_definition?(node, parent: parent)
        fully_qualify_constant(ancestors)
      else
        begin
          NodeHelpers.constant_name(node)
        rescue NodeHelpers::TypeError
          nil
        end
      end
    end

    private

    #: (AST::Node? parent) -> bool
    def root_constant?(parent)
      !(parent && NodeHelpers.constant?(parent))
    end

    #: (AST::Node node, parent: AST::Node) -> bool?
    def constant_in_module_or_class_definition?(node, parent:)
      parent_name = NodeHelpers.module_name_from_definition(parent)
      parent_name && parent_name == NodeHelpers.constant_name(node)
    end

    #: (Array[AST::Node] ancestors) -> String
    def fully_qualify_constant(ancestors)
      # We're defining a class with this name, in which case the constant is implicitly fully qualified by its
      # enclosing namespace
      "::" + NodeHelpers.parent_module_name(ancestors: ancestors)
    end
  end

  private_constant :ConstNodeInspector
end
