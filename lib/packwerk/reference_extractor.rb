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
      params(
        node: ::Parser::AST::Node,
        ancestors: T::Array[::Parser::AST::Node],
        absolute_file: String
      ).returns(T.nilable(UnresolvedReference))
    end
    def reference_from_node(node, ancestors:, absolute_file:)
      constant_name = T.let(nil, T.nilable(String))

      @constant_name_inspectors.each do |inspector|
        constant_name = inspector.constant_name_from_node(node, ancestors: ancestors)

        break if constant_name
      end

      if constant_name
        reference_from_constant(
          constant_name,
          node: node,
          ancestors: ancestors,
          absolute_file: absolute_file
        )
      end
    end

    sig do
      params(
        unresolved_references_and_offenses: T::Array[T.any(UnresolvedReference, Offense)],
        context_provider: ConstantDiscovery
      ).returns(T::Array[T.any(Reference, Offense)])
    end
    def self.get_fully_qualified_references_and_offenses_from(unresolved_references_and_offenses, context_provider)
      fully_qualified_references_and_offenses = T.let([], T::Array[T.any(Reference, Offense)])

      unresolved_references_and_offenses.each do |unresolved_references_or_offense|
        if unresolved_references_or_offense.is_a?(Offense)
          fully_qualified_references_and_offenses << unresolved_references_or_offense

          next
        end

        unresolved_reference = unresolved_references_or_offense

        constant =
          context_provider.context_for(
            unresolved_reference.constant_name,
            current_namespace_path: unresolved_reference.namespace_path
          )

        next if constant.nil?

        package_for_constant = constant.package

        next if package_for_constant.nil?

        source_package = context_provider.package_from_path(unresolved_reference.relative_path)

        next if source_package == package_for_constant

        fully_qualified_references_and_offenses << Reference.new(
          source_package,
          unresolved_reference.relative_path,
          constant,
          unresolved_reference.source_location
        )
      end

      fully_qualified_references_and_offenses
    end

    private

    sig do
      params(
        constant_name: String,
        node: ::Parser::AST::Node,
        ancestors: T::Array[::Parser::AST::Node],
        absolute_file: String
      ).returns(T.nilable(UnresolvedReference))
    end
    def reference_from_constant(constant_name, node:, ancestors:, absolute_file:)
      namespace_path = Node.enclosing_namespace_path(node, ancestors: ancestors)

      return if local_reference?(constant_name, Node.name_location(node), namespace_path)

      relative_file = Pathname.new(absolute_file).relative_path_from(@root_path).to_s
      location = Node.location(node)

      UnresolvedReference.new(
        constant_name,
        namespace_path,
        relative_file,
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
