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
          custom_associations: configuration.custom_associations,
          cache_enabled: configuration.cache_enabled?,
          config_path: configuration.config_path,
        )
      end
    end

    def initialize(
      root_path:,
      load_paths:,
      package_paths: nil,
      inflector: nil,
      custom_associations: [],
      checker_classes: DEFAULT_CHECKERS,
      cache_enabled: false,
      config_path: nil
    )
      @root_path = root_path
      @load_paths = load_paths
      @package_paths = package_paths
      @inflector = inflector
      @custom_associations = custom_associations
      @checker_classes = checker_classes
      @cache_enabled = cache_enabled
      @config_path = config_path
    end

    sig { params(file: String).returns(T::Array[Packwerk::Offense]) }
    def process_file(file:)
      unresolved_references_and_offenses = file_processor.call(file)
      references_and_offenses = ReferenceExtractor.get_fully_qualified_references_and_offenses_from(
        unresolved_references_and_offenses,
        context_provider
      )
      reference_checker = ReferenceChecking::ReferenceChecker.new(checkers)
      references_and_offenses.flat_map { |reference| reference_checker.call(reference) }
    end

    private

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
      @cache ||= Cache.new(enable_cache: @cache_enabled, config_path: @config_path)
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
