# typed: false
# frozen_string_literal: true

require "packwerk/node"

module Packwerk
  class NodeVisitor
    def initialize(node_processor:)
      @node_processor = node_processor
    end

    def visit(node, ancestors:, result:)
      offenses = @node_processor.call(node, ancestors)
      result.concat(offenses) unless offenses.nil? || offenses.empty?

      child_ancestors = [node] + ancestors
      Node.each_child(node) do |child|
        visit(child, ancestors: child_ancestors, result: result)
      end
    end
  end
end
