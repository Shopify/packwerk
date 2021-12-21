# typed: true
# frozen_string_literal: true

module Packwerk
  # Extracts a possible constant reference from a given AST node.
  class ReferenceExtractor
    extend T::Sig

    sig do
      params(
        constant_name_inspectors: T::Array[Packwerk::ConstantNameInspector],
        root_node: ::AST::Node,
        root_path: String,
      ).void
    end
    def initialize(
      constant_name_inspectors:,
      root_node:,
      root_path:
    )
      @constant_name_inspectors = constant_name_inspectors
      @root_path = root_path
      @local_constant_definitions = ParsedConstantDefinitions.new(root_node: root_node)
    end

    sig do
      params(node: Parser::AST::Node, ancestors: T::Array[Parser::AST::Node],
file_path: String).returns(T.nilable(PartiallyQualifiedReference))
    end
    def reference_from_node(node, ancestors:, file_path:)
      constant_name = T.let(nil, T.nilable(String))

      @constant_name_inspectors.each do |inspector|
        constant_name = inspector.constant_name_from_node(node, ancestors: ancestors)
        break if constant_name
      end

      reference_from_constant(constant_name, node: node, ancestors: ancestors, file_path: file_path) if constant_name
    end

    sig do
      params(
        partially_qualified_references_and_offenses: T::Array[T.any(PartiallyQualifiedReference, Offense)],
        context_provider: ConstantDiscovery
      ).returns(T::Array[T.any(Reference, Offense)])
    end
    def self.get_fully_qualified_references_and_offenses_from(
      partially_qualified_references_and_offenses,
      context_provider
    )
      fully_qualified_references_and_offenses = T.let([], T::Array[T.any(Reference, Offense)])

      partially_qualified_references_and_offenses.each do |partially_qualified_references_or_offense|
        if partially_qualified_references_or_offense.is_a?(Offense)
          fully_qualified_references_and_offenses << partially_qualified_references_or_offense
          next
        end

        partially_qualified_reference = partially_qualified_references_or_offense

        constant =
          context_provider.context_for(
            partially_qualified_reference.constant_name,
            current_namespace_path: partially_qualified_reference.namespace_path
          )

        next if constant&.package.nil?

        source_package = context_provider.package_from_path(partially_qualified_reference.relative_path)

        next if source_package == constant.package

        fully_qualified_references_and_offenses << Reference.new(
          source_package,
          partially_qualified_reference.relative_path,
          constant,
          partially_qualified_reference.source_location
        )
      end

      fully_qualified_references_and_offenses
    end

    private

    sig do
      params(
        constant_name: String,
        node: Parser::AST::Node,
        ancestors: T::Array[Parser::AST::Node],
        file_path: String
      ).returns(T.nilable(PartiallyQualifiedReference))
    end
    def reference_from_constant(constant_name, node:, ancestors:, file_path:)
      namespace_path = Node.enclosing_namespace_path(node, ancestors: ancestors)
      return if local_reference?(constant_name, Node.name_location(node), namespace_path)

      relative_path = Pathname.new(file_path).relative_path_from(@root_path).to_s
      location = Node.location(node)

      PartiallyQualifiedReference.new(
        constant_name,
        namespace_path,
        relative_path,
        location
      )
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
