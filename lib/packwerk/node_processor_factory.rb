# typed: strict
# frozen_string_literal: true

module Packwerk
  class NodeProcessorFactory < T::Struct

    const :root_path, String
    const :constant_name_inspectors, T::Array[ConstantNameInspector]

    #: (relative_file: String, node: AST::Node) -> NodeProcessor
    def for(relative_file:, node:)
      NodeProcessor.new(
        reference_extractor: reference_extractor(node: node),
        relative_file: relative_file,
      )
    end

    private

    #: (node: AST::Node) -> ReferenceExtractor
    def reference_extractor(node:)
      ReferenceExtractor.new(
        constant_name_inspectors: constant_name_inspectors,
        root_node: node,
        root_path: root_path,
      )
    end
  end

  private_constant :NodeProcessorFactory
end
