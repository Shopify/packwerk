# typed: strict
# frozen_string_literal: true

module Packwerk
  # Extracts a constant name from an AST node of type :const
  class ConstNodeInspector
    extend T::Sig
    include ConstantNameInspector

    sig do
      override
        .params(node: AST::Node, ancestors: T::Array[AST::Node])
        .returns(T.nilable(String))
    end
    def constant_name_from_node(node, ancestors:)
      return nil unless Node.constant?(node)
      parent = ancestors.first
      return nil unless root_constant?(parent)

      if parent && constant_in_module_or_class_definition?(node, parent: parent)
        fully_qualify_constant(ancestors)
      else
        begin
          Node.constant_name(node)
        rescue Node::TypeError
          nil
        end
      end
    end

    private

    # Only process the root `const` node for namespaced constant references. For example, in the
    # reference `Spam::Eggs::Thing`, we only process the const node associated with `Spam`.
    sig { params(parent: T.nilable(AST::Node)).returns(T::Boolean) }
    def root_constant?(parent)
      !(parent && Node.constant?(parent))
    end

    sig { params(node: AST::Node, parent: AST::Node).returns(T.nilable(T::Boolean)) }
    def constant_in_module_or_class_definition?(node, parent:)
      parent_name = Node.module_name_from_definition(parent)
      parent_name && parent_name == Node.constant_name(node)
    end

    sig { params(ancestors: T::Array[AST::Node]).returns(String) }
    def fully_qualify_constant(ancestors)
      # We're defining a class with this name, in which case the constant is implicitly fully qualified by its
      # enclosing namespace
      "::" + Node.parent_module_name(ancestors: ancestors)
    end
  end
end
