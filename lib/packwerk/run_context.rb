# typed: strict
# frozen_string_literal: true

require "constant_resolver"

module Packwerk
  # Holds the context of a Packwerk run across multiple files.
  class RunContext
    extend T::Sig

    DEFAULT_CHECKERS = T.let([
      ::Packwerk::ReferenceChecking::Checkers::DependencyChecker.new,
      ::Packwerk::ReferenceChecking::Checkers::PrivacyChecker.new,
    ], T::Array[ReferenceChecking::Checkers::Checker])

    class << self
      extend T::Sig

      sig do
        params(configuration: Configuration).returns(RunContext)
      end
      def from_configuration(configuration)
        inflector = ActiveSupport::Inflector

        new(
          root_path: configuration.root_path,
          load_paths: configuration.load_paths,
          package_paths: configuration.package_paths,
          inflector: inflector,
          custom_associations: configuration.custom_associations,
          cache_enabled: configuration.cache_enabled?,
          cache_directory: configuration.cache_directory,
          config_path: configuration.config_path,
        )
      end
    end

    sig do
      params(
        root_path: String,
        load_paths: T::Array[String],
        inflector: T.class_of(ActiveSupport::Inflector),
        cache_directory: Pathname,
        config_path: T.nilable(String),
        package_paths: T.nilable(T.any(T::Array[String], String)),
        custom_associations: AssociationInspector::CustomAssociations,
        checkers: T::Array[ReferenceChecking::Checkers::Checker],
        cache_enabled: T::Boolean,
      ).void
    end
    def initialize(
      root_path:,
      load_paths:,
      inflector:,
      cache_directory:,
      config_path: nil,
      package_paths: nil,
      custom_associations: [],
      checkers: DEFAULT_CHECKERS,
      cache_enabled: false
    )
      @root_path = root_path
      @load_paths = load_paths
      @package_paths = package_paths
      @inflector = inflector
      @custom_associations = custom_associations
      @checkers = checkers
      @cache_enabled = cache_enabled
      @cache_directory = cache_directory
      @config_path = config_path

      @file_processor = T.let(nil, T.nilable(FileProcessor))
      @context_provider = T.let(nil, T.nilable(ConstantDiscovery))
      @cache = T.let(nil, T.nilable(Cache))
    end

    sig { params(absolute_file_path: String).returns(T::Array[Packwerk::Offense]) }
    def process_file(absolute_file_path:)
      unresolved_references_and_offenses = file_processor.call(absolute_file_path)
      references_and_offenses = ReferenceExtractor.get_fully_qualified_references_and_offenses_from(
        unresolved_references_and_offenses,
        context_provider
      )
      reference_checker = ReferenceChecking::ReferenceChecker.new(@checkers)
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
        root_path: @root_path,
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
        root_path: @root_path,
        load_paths: @load_paths,
        inflector: @inflector,
      )
    end

    sig { returns(Cache) }
    def cache
      @cache ||= Cache.new(enable_cache: @cache_enabled, cache_directory: @cache_directory, config_path: @config_path)
    end

    sig { returns(PackageSet) }
    def package_set
      ::Packwerk::PackageSet.load_all_from(@root_path, package_pathspec: @package_paths)
    end

    sig { returns(T::Array[ConstantNameInspector]) }
    def constant_name_inspectors
      [
        ::Packwerk::ConstNodeInspector.new,
        ::Packwerk::AssociationInspector.new(inflector: @inflector, custom_associations: @custom_associations),
      ]
    end
  end
end
