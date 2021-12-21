# typed: true
# frozen_string_literal: true

require "constant_resolver"

module Packwerk
  # Holds the context of a Packwerk run across multiple files.
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
      ::Packwerk::ReferenceChecking::Checkers::DependencyChecker,
      ::Packwerk::ReferenceChecking::Checkers::PrivacyChecker,
    ]

    class << self
      def from_configuration(configuration)
        inflector = ActiveSupport::Inflector
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

    sig { params(file: String).returns(T::Array[Packwerk::Offense]) }
    def process_file(file:)

      partially_qualified_references_and_offenses = file_processor.call(file)
      references_and_offenses = get_fully_qualified_references_and_offenses_from(
        partially_qualified_references_and_offenses
      )
      reference_checker = ReferenceChecking::ReferenceChecker.new(checkers)
      references_and_offenses.flat_map { |reference| reference_checker.call(reference) }
    end

    private

    sig do
      params(partially_qualified_references_and_offenses: T::Array[T.any(PartiallyQualifiedReference,
        Offense)]).returns(T::Array[T.any(Reference, Offense)])
    end
    def get_fully_qualified_references_and_offenses_from(partially_qualified_references_and_offenses)
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

        Reference.new(
          source_package,
          partially_qualified_reference.relative_path,
          constant,
          partially_qualified_reference.source_location
        )
      end

      fully_qualified_references_and_offenses
    end

    sig { returns(FileProcessor) }
    def file_processor
      @file_processor ||= FileProcessor.new(node_processor_factory: node_processor_factory, cache: cache)
    end

    sig { returns(NodeProcessorFactory) }
    def node_processor_factory
      NodeProcessorFactory.new(
        context_provider: context_provider,
        root_path: root_path,
        constant_name_inspectors: constant_name_inspectors
      )
    end

    sig { returns(ConstantDiscovery) }
    def context_provider
      @context_provider ||= ::Packwerk::ConstantDiscovery.new(
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

    sig { returns(Cache) }
    def cache
      @cache ||= Cache.new
    end

    sig { returns(PackageSet) }
    def package_set
      ::Packwerk::PackageSet.load_all_from(root_path, package_pathspec: package_paths)
    end

    sig { returns(T::Array[ReferenceChecking::Checkers::Checker]) }
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
