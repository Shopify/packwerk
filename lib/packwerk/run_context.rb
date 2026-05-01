# typed: strict
# frozen_string_literal: true

require "constant_resolver"

module Packwerk
  # Holds the context of a Packwerk run across multiple files.
  class RunContext
    class << self
      #: (Configuration configuration) -> RunContext
      def from_configuration(configuration)
        new(
          root_path: configuration.root_path,
          load_paths: configuration.load_paths,
          package_paths: configuration.package_paths,
          inflector: ActiveSupport::Inflector,
          custom_associations: configuration.custom_associations,
          associations_exclude: configuration.associations_exclude,
          exclude: configuration.exclude,
          cache_enabled: configuration.cache_enabled?,
          cache_directory: configuration.cache_directory,
          config_path: configuration.config_path,
        )
      end
    end

    #: (
    #|   root_path: String,
    #|   load_paths: Hash[String, Module[top]],
    #|   inflector: singleton(ActiveSupport::Inflector),
    #|   cache_directory: Pathname,
    #|   ?config_path: String?,
    #|   ?package_paths: (Array[String] | String)?,
    #|   ?custom_associations: AssociationInspector::custom_associations,
    #|   ?associations_exclude: Array[String],
    #|   ?exclude: Array[String],
    #|   ?checkers: Array[Checker],
    #|   ?cache_enabled: bool
    #| ) -> void
    def initialize(
      root_path:,
      load_paths:,
      inflector:,
      cache_directory:,
      config_path: nil,
      package_paths: nil,
      custom_associations: [],
      associations_exclude: [],
      exclude: [],
      checkers: Checker.all,
      cache_enabled: false
    )
      @root_path = root_path
      @load_paths = load_paths
      @package_paths = package_paths
      @inflector = inflector
      @custom_associations = custom_associations
      @associations_exclude = associations_exclude
      @checkers = checkers
      @cache_enabled = cache_enabled
      @cache_directory = cache_directory
      @config_path = config_path
      @exclude = exclude

      @file_processor = nil #: FileProcessor?
      @context_provider = nil #: ConstantDiscovery?
      @package_set = nil #: PackageSet?
      # We need to initialize this before we fork the process, see https://github.com/Shopify/packwerk/issues/182
      @cache = Cache.new(enable_cache: @cache_enabled, cache_directory: @cache_directory, config_path: @config_path) #: Cache
    end

    #: (relative_file: String) -> Array[Packwerk::Offense]
    def process_file(relative_file:)
      processed_file = file_processor.call(relative_file)

      references = ReferenceExtractor.get_fully_qualified_references_from(
        processed_file.unresolved_references,
        context_provider
      )
      reference_checker = ReferenceChecking::ReferenceChecker.new(@checkers)

      processed_file.offenses + references.flat_map { |reference| reference_checker.call(reference) }
    end

    #: -> PackageSet
    def package_set
      @package_set ||= ::Packwerk::PackageSet.load_all_from(@root_path, package_pathspec: @package_paths)
    end

    private

    #: -> FileProcessor
    def file_processor
      @file_processor ||= FileProcessor.new(node_processor_factory: node_processor_factory, cache: @cache)
    end

    #: -> NodeProcessorFactory
    def node_processor_factory
      NodeProcessorFactory.new(
        root_path: @root_path,
        constant_name_inspectors: constant_name_inspectors
      )
    end

    #: -> ConstantDiscovery
    def context_provider
      @context_provider ||= ConstantDiscovery.new(
        constant_resolver: resolver,
        packages: package_set
      )
    end

    #: -> ConstantResolver
    def resolver
      ConstantResolver.new(
        root_path: @root_path,
        load_paths: @load_paths,
        inflector: @inflector,
        exclude: @exclude,
      )
    end

    #: -> Array[ConstantNameInspector]
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

    #: (Array[String] relative_globs) -> FilesForProcessing::relative_file_set
    def relative_files_for_globs(relative_globs)
      Set.new(relative_globs.flat_map { |glob| Dir[glob] })
    end
  end

  private_constant :RunContext
end
