# typed: true
# frozen_string_literal: true

module Packwerk
  # Processes a single node in an abstract syntax tree (AST) using the provided checkers.
  class NodeProcessor
    extend T::Sig

    sig do
      params(
        reference_extractor: ReferenceExtractor,
        filename: String,
      ).void
    end
    def initialize(reference_extractor:, filename:)
      @reference_extractor = reference_extractor
      @filename = filename
    end

    sig do
      params(
        node: AST::Node,
        ancestors: T::Array[AST::Node]
      ).returns(T.nilable(Packwerk::Reference))
    end
    def call(node, ancestors)
      return unless Node.method_call?(node) || Node.constant?(node)
      @reference_extractor.reference_from_node(node, ancestors: ancestors, file_path: @filename)
    end
  end
end
