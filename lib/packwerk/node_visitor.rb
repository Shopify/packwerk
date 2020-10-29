# typed: false
# frozen_string_literal: true

require "packwerk/node"

module Packwerk
  class NodeVisitor
    def initialize(node_processor:)
      @node_processor = node_processor
    end

    def visit(node, ancestors:, result:)
      offense = @node_processor.call(node, ancestors: ancestors)
      result << offense if offense

      child_ancestors = [node] + ancestors
      node.each_child do |child|
        visit(child, ancestors: child_ancestors, result: result)
      end
    end
  end
end
