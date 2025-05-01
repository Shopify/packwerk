# typed: strict
# frozen_string_literal: true

module Packwerk
  # Holds the context of a Packwerk run across multiple files.
  class RunContext
    extend T::Sig

    class << self
      extend T::Sig

      sig do
        params(configuration: Configuration).returns(RunContext)
      end
      def from_configuration(configuration)
        new(
          root_path: configuration.root_path,
          package_paths: configuration.package_paths,
          inflector: ActiveSupport::Inflector,
          custom_associations: configuration.custom_associations,
          associations_exclude: configuration.associations_exclude,
          cache_enabled: configuration.cache_enabled?,
          cache_directory: configuration.cache_directory,
          config_path: configuration.config_path,
          loaders: configuration.loaders
        )
      end
    end

    sig do
      params(
        root_path: String,
        inflector: T.class_of(ActiveSupport::Inflector),
        cache_directory: Pathname,
        config_path: T.nilable(String),
        package_paths: T.nilable(T.any(T::Array[String], String)),
        custom_associations: AssociationInspector::CustomAssociations,
        associations_exclude: T::Array[String],
        checkers: T::Array[Checker],
        cache_enabled: T::Boolean,
        loaders: T::Enumerable[Zeitwerk::Loader]
      ).void
    end
    def initialize(
      root_path:,
      inflector:,
      cache_directory:,
      config_path: nil,
      package_paths: nil,
      custom_associations: [],
      associations_exclude: [],
      checkers: Checker.all,
      cache_enabled: false,
      loaders: []
    )
      @root_path = root_path
      @loaders = loaders
      @package_paths = package_paths
      @inflector = inflector
      @custom_associations = custom_associations
      @associations_exclude = associations_exclude
      @checkers = checkers
      @cache_enabled = cache_enabled
      @cache_directory = cache_directory
      @config_path = config_path

      @file_processor = T.let(nil, T.nilable(FileProcessor))
      @context_provider = T.let(nil, T.nilable(ConstantDiscovery))
      @package_set = T.let(nil, T.nilable(PackageSet))
      # We need to initialize this before we fork the process, see https://github.com/Shopify/packwerk/issues/182
      @cache = T.let(
        Cache.new(enable_cache: @cache_enabled, cache_directory: @cache_directory, config_path: @config_path), Cache
      )
    end

    sig { params(relative_file: String).returns(T::Array[Packwerk::Offense]) }
    def process_file(relative_file:)
      processed_file = file_processor.call(relative_file)

      references = ReferenceExtractor.get_fully_qualified_references_from(
        processed_file.unresolved_references,
        context_provider
      )
      reference_checker = ReferenceChecking::ReferenceChecker.new(@checkers)

      processed_file.offenses + references.flat_map { |reference| reference_checker.call(reference) }
    end

    sig { returns(PackageSet) }
    def package_set
      @package_set ||= ::Packwerk::PackageSet.load_all_from(@root_path, package_pathspec: @package_paths)
    end

    private

    sig { returns(FileProcessor) }
    def file_processor
      @file_processor ||= FileProcessor.new(node_processor_factory: node_processor_factory, cache: @cache)
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
      @context_provider ||= ConstantDiscovery.new(
        package_set,
        root_path: @root_path,
        loaders:   @loaders
      )
    end

    sig { returns(T::Array[ConstantNameInspector]) }
    def constant_name_inspectors
      [
        ConstNodeInspector.new,
        AssociationInspector.new(
          inflector: @inflector,
          custom_associations: @custom_associations,
          excluded_files: relative_files_for_globs(@associations_exclude),
        ),
      ]
    end

    sig { params(relative_globs: T::Array[String]).returns(FilesForProcessing::RelativeFileSet) }
    def relative_files_for_globs(relative_globs)
      Set.new(relative_globs.flat_map { |glob| Dir[glob] })
    end
  end

  private_constant :RunContext
end
