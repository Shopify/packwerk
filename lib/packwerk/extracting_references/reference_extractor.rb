# typed: true
# frozen_string_literal: true

module Packwerk
  # extracts a possible constant reference from a given AST node
  class ReferenceExtractor
    extend T::Sig

    sig do
      params(
        context_provider: Packwerk::ConstantDiscovery,
        constant_name_inspectors: T::Array[Packwerk::ConstantNameInspector],
        root_node: ::AST::Node,
        root_path: String,
      ).void
    end
    def initialize(
      context_provider:,
      constant_name_inspectors:,
      root_node:,
      root_path:
    )
      @context_provider = context_provider
      @constant_name_inspectors = constant_name_inspectors
      @root_path = root_path
      @local_constant_definitions = ParsedConstantDefinitions.new(root_node: root_node)
    end

    def reference_from_node(node, ancestors:, file_path:)
      constant_name = T.let(nil, T.nilable(String))

      @constant_name_inspectors.each do |inspector|
        constant_name = inspector.constant_name_from_node(node, ancestors: ancestors)
        break if constant_name
      end

      reference_from_constant(constant_name, node: node, ancestors: ancestors, file_path: file_path) if constant_name
    end

    private

    def reference_from_constant(constant_name, node:, ancestors:, file_path:)
      namespace_path = Node.enclosing_namespace_path(node, ancestors: ancestors)
      return if local_reference?(constant_name, Node.name_location(node), namespace_path)

      constant =
        @context_provider.context_for(
          constant_name,
          current_namespace_path: namespace_path
        )

      return if constant&.package.nil?

      relative_path =
        Pathname.new(file_path)
          .relative_path_from(@root_path).to_s

      source_package = @context_provider.package_from_path(relative_path)

      return if source_package == constant.package

      Reference.new(source_package, relative_path, constant)
    end

    def local_reference?(constant_name, name_location, namespace_path)
      @local_constant_definitions.local_reference?(
        constant_name,
        location: name_location,
        namespace_path: namespace_path
      )
    end
  end
end
