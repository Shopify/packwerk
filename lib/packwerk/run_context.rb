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

    class ProcessedFileResult < T::Struct
      const :file, String
      const :references, T::Array[Reference]
      const :offenses, T::Array[Offense]
    end

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

    sig { params(file: String).returns(ProcessedFileResult) }
    def process_file(file:)
      references_and_offenses = file_processor.call(file)
      reference_checker = ReferenceChecking::ReferenceChecker.new(checkers)
      offenses = references_and_offenses.flat_map { |reference| reference_checker.call(reference) }
      references = references_and_offenses.select { |r| r.is_a?(Reference) }

      ProcessedFileResult.new(
        file: file,
        offenses: offenses,
        references: T.cast(references, T::Array[Reference])
      )
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
