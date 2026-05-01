# typed: strict
# frozen_string_literal: true

module Packwerk
  class NodeProcessorFactory
    #: String
    attr_reader :root_path

    #: Array[ConstantNameInspector]
    attr_reader :constant_name_inspectors

    #: (root_path: String, constant_name_inspectors: Array[ConstantNameInspector]) -> void
    def initialize(root_path:, constant_name_inspectors:)
      @root_path = root_path
      @constant_name_inspectors = constant_name_inspectors
    end

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
