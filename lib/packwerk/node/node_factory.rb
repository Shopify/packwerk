# typed: true
# frozen_string_literal: true

require "packwerk/node"

module Packwerk
  class NodeFactory
    class << self
      def for(node)
        return node if node.class == Node

        case node.type
        when BlockNode::TYPE
          BlockNode.new(node)
        when ClassNode::TYPE
          ClassNode.new(node)
        when ConstantNode::TYPE
          ConstantNode.new(node)
        when ConstantAssignmentNode::TYPE
          ConstantAssignmentNode.new(node)
        when ConstantRootNamespaceNode::TYPE
          ConstantRootNamespaceNode.new(node)
        when HashNode::TYPE
          HashNode.new(node)
        when HashPairNode::TYPE
          HashPairNode.new(node)
        when MethodCallNode::TYPE
          MethodCallNode.new(node)
        when ModuleNode::TYPE
          ModuleNode.new(node)
        when StringNode::TYPE
          StringNode.new(node)
        when SymbolNode::TYPE
          SymbolNode.new(node)
        else
          Node.new(node)
        end
      end
    end
  end
end
