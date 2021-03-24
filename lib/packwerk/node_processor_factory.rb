# typed: strict
# frozen_string_literal: true

require "packwerk/constant_name_inspector"
require "packwerk/checker"

module Packwerk
  class NodeProcessorFactory < T::Struct
    extend T::Sig

    const :root_path, String
    const :context_provider, Packwerk::ConstantDiscovery
    const :constant_name_inspectors, T::Array[ConstantNameInspector]
    const :checkers, T::Array[Checker]

    sig { params(filename: String, node: AST::Node).returns(NodeProcessor) }
    def for(filename:, node:)
      ::Packwerk::NodeProcessor.new(
        reference_extractor: reference_extractor(node: node),
        filename: filename,
        checkers: checkers,
      )
    end

    private

    sig { params(node: AST::Node).returns(::Packwerk::ReferenceExtractor) }
    def reference_extractor(node:)
      ::Packwerk::ReferenceExtractor.new(
        context_provider: context_provider,
        constant_name_inspectors: constant_name_inspectors,
        root_node: node,
        root_path: root_path,
      )
    end
  end
end
