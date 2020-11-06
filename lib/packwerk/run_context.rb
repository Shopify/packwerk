# typed: true
# frozen_string_literal: true

require "constant_resolver"

require "packwerk/association_inspector"
require "packwerk/checking_deprecated_references"
require "packwerk/constant_discovery"
require "packwerk/const_node_inspector"
require "packwerk/dependency_checker"
require "packwerk/file_processor"
require "packwerk/inflector"
require "packwerk/node_processor"
require "packwerk/package_set"
require "packwerk/privacy_checker"
require "packwerk/reference_extractor"
require "packwerk/node_processor_factory"

module Packwerk
  class RunContext
    extend T::Sig

    attr_reader(
      :checkers,
      :constant_name_inspectors,
      :context_provider,
      :root_path,
      :node_processor_class,
      :reference_lister
    )

    DEFAULT_CHECKERS = [
      ::Packwerk::DependencyChecker,
      ::Packwerk::PrivacyChecker,
    ]

    class << self
      def from_configuration(configuration, reference_lister: nil)
        default_reference_lister = reference_lister ||
          ::Packwerk::CheckingDeprecatedReferences.new(configuration.root_path)
        inflector = ::Packwerk::Inflector.from_file(configuration.inflections_file)
        new(
          root_path: configuration.root_path,
          load_paths: configuration.load_paths,
          package_paths: configuration.package_paths,
          inflector: inflector,
          custom_associations: configuration.custom_associations,
          reference_lister: default_reference_lister,
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
      node_processor_class: NodeProcessor,
      reference_lister: nil
    )
      @root_path = root_path

      resolver = ConstantResolver.new(
        root_path: @root_path,
        load_paths: load_paths,
        inflector: inflector,
      )

      package_set = ::Packwerk::PackageSet.load_all_from(@root_path, package_pathspec: package_paths)

      @context_provider = ::Packwerk::ConstantDiscovery.new(
        constant_resolver: resolver,
        packages: package_set
      )

      @reference_lister = reference_lister || ::Packwerk::CheckingDeprecatedReferences.new(@root_path)

      @checkers = checker_classes.map(&:new)

      @constant_name_inspectors = [
        ::Packwerk::ConstNodeInspector.new,
        ::Packwerk::AssociationInspector.new(inflector: inflector, custom_associations: custom_associations),
      ]

      @node_processor_class = node_processor_class
    end

    sig { params(file: String).returns(T::Array[T.nilable(::Packwerk::Offense)]) }
    def process_file(file:)
      file_processor.call(file)
    end

    private

    sig { returns(FileProcessor) }
    def file_processor
      @file_processor ||= FileProcessor.new(node_processor_factory: node_processor_factory)
    end

    sig { returns(NodeProcessorFactory) }
    def node_processor_factory
      NodeProcessorFactory.new(
        node_processor_class: node_processor_class,
        context_provider: context_provider,
        checkers: checkers,
        root_path: root_path,
        constant_name_inspectors: constant_name_inspectors,
        reference_lister: reference_lister
      )
    end
  end
end
