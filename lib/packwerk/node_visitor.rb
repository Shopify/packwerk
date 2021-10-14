# typed: false
# frozen_string_literal: true

module Packwerk
  class NodeVisitor
    def initialize(node_processor:)
      @node_processor = node_processor
    end

    def visit(node, ancestors:, result:)
      reference = @node_processor.call(node, ancestors)
      result << reference if reference

      child_ancestors = [node] + ancestors
      Node.each_child(node) do |child|
        visit(child, ancestors: child_ancestors, result: result)
      end
    end
  end
end
