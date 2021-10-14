# typed: true
# frozen_string_literal: true

require "constant_resolver"

module Packwerk
  # Packwerk used to run as a part of Rubocop.
  # Now that Packwerk is a standalone script, this structure shouldn't be necessary.
  class RunContext
    extend T::Sig

    attr_reader(
      :root_path,
      :load_paths,
      :package_paths,
      :inflector,
      :custom_associations,
      :checker_classes,
    )

    DEFAULT_CHECKERS = [
      ::Packwerk::DependencyChecker,
      ::Packwerk::PrivacyChecker,
    ]

    class << self
      def from_configuration(configuration)
        inflector = ::Packwerk::Inflector.from_file(configuration.inflections_file)
        new(
          root_path: configuration.root_path,
          load_paths: configuration.load_paths,
          package_paths: configuration.package_paths,
          inflector: inflector,
          custom_associations: configuration.custom_associations
        )
      end
    end

    def initialize(
      root_path:,
      load_paths:,
      package_paths: nil,
      inflector: nil,
      custom_associations: [],
      checker_classes: DEFAULT_CHECKERS
    )
      @root_path = root_path
      @load_paths = load_paths
      @package_paths = package_paths
      @inflector = inflector
      @custom_associations = custom_associations
      @checker_classes = checker_classes
    end

    sig { params(file: String).returns(T::Array[T.nilable(::Packwerk::Offense)]) }
    def process_file(file:)
      # 1. file path to node
      # It needs to return ancestors relative to node
      node, ancestors = file_processor.call(file)

      # Inside NodeProcessor - @reference_extractor.reference_from_node(node, ancestors: ancestors, file_path: @filename)
      # 2. node to constant
      @constant_name_inspectors.each do |inspector|
        constant_name = inspector.constant_name_from_node(node, ancestors: ancestors)
        break if constant_name
      end

      # Inside ReferenceExtractor - reference_from_constant(constant_name, node: node, ancestors: ancestors, file_path: file_path) if constant_name
      # 3. constant to reference
      namespace_path = Node.enclosing_namespace_path(node, ancestors: ancestors)
      return if local_reference?(constant_name, Node.name_location(node), namespace_path)

      constant =
        @context_provider.context_for(
          constant_name,
          current_namespace_path: namespace_path
        )
      return if constant&.package.nil?

      relative_path = Pathname.new(file_path).relative_path_from(@root_path).to_s

      source_package = @context_provider.package_from_path(relative_path)
      return if source_package == constant.package

      Reference.new(source_package, relative_path, constant)

      # Inside NodeProcessor
      # 4. reference to an offence
      @checkers.each_with_object([]) do |checker, violations|
        next unless checker.invalid_reference?(reference)
        offense = Packwerk::ReferenceOffense.new(
          location: Node.location(node),
          reference: reference,
          violation_type: checker.violation_type
        )
        violations << offense
      end

    end

    private

    sig { returns(FileProcessor) }
    def file_processor
      @file_processor ||= FileProcessor.new(node_processor_factory: node_processor_factory)
    end

    sig { returns(NodeProcessorFactory) }
    def node_processor_factory
      NodeProcessorFactory.new(
        context_provider: context_provider,
        checkers: checkers,
        root_path: root_path,
        constant_name_inspectors: constant_name_inspectors
      )
    end

    sig { returns(ConstantDiscovery) }
    def context_provider
      ::Packwerk::ConstantDiscovery.new(
        constant_resolver: resolver,
        packages: package_set
      )
    end

    sig { returns(ConstantResolver) }
    def resolver
      ConstantResolver.new(
        root_path: root_path,
        load_paths: load_paths,
        inflector: inflector,
      )
    end

    sig { returns(PackageSet) }
    def package_set
      ::Packwerk::PackageSet.load_all_from(root_path, package_pathspec: package_paths)
    end

    sig { returns(T::Array[Checker]) }
    def checkers
      checker_classes.map(&:new)
    end

    sig { returns(T::Array[ConstantNameInspector]) }
    def constant_name_inspectors
      [
        ::Packwerk::ConstNodeInspector.new,
        ::Packwerk::AssociationInspector.new(inflector: inflector, custom_associations: custom_associations),
      ]
    end
  end
end
