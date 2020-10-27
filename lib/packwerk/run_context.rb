# typed: true
# frozen_string_literal: true

require "active_support/inflector"
require "constant_resolver"

require "packwerk/association_inspector"
require "packwerk/checking_deprecated_references"
require "packwerk/constant_discovery"
require "packwerk/const_node_inspector"
require "packwerk/dependency_checker"
require "packwerk/node_processor"
require "packwerk/package_set"
require "packwerk/privacy_checker"
require "packwerk/reference_extractor"

module Packwerk
  class RunContext
    attr_reader(
      :root_path,
      :load_paths,
      :package_paths,
      :inflector,
      :custom_associations,
      :checker_classes,
      :node_processor_class,
      :reference_lister,
    )

    DEFAULT_CHECKERS = [
      ::Packwerk::DependencyChecker,
      ::Packwerk::PrivacyChecker,
    ]

    class << self
      def from_configuration(configuration, reference_lister: nil)
        new(
          root_path: configuration.root_path,
          load_paths: configuration.load_paths,
          package_paths: configuration.package_paths,
          inflector: ActiveSupport::Inflector,
          custom_associations: configuration.custom_associations,
          reference_lister: reference_lister,
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
      @load_paths = load_paths
      @package_paths = package_paths
      @inflector = inflector
      @custom_associations = custom_associations
      @checker_classes = checker_classes
      @reference_lister = reference_lister
      @node_processor_class = node_processor_class
    end

    def node_processor_for(filename:, ast_node:)
      node_processor_class.new(
        reference_extractor: reference_extractor_for_ast(ast_node),
        reference_lister: reference_lister,
        filename: filename,
        checkers: checkers,
      )
    end

    private

    def reference_extractor_for_ast(ast_node)
      ::Packwerk::ReferenceExtractor.new(
        context_provider: context_provider,
        constant_name_inspectors: constant_name_inspectors,
        root_node: ast_node,
        root_path: root_path,
      )
    end

    def context_provider
      @context_provider ||= create_context_provider
    end

    def create_context_provider
      package_set = ::Packwerk::PackageSet.load_all_from(root_path, package_pathspec: package_paths)
      ::Packwerk::ConstantDiscovery.new(constant_resolver: resolver, packages: package_set)
    end

    def constant_name_inspectors
      @constant_name_inspectors ||= [
        ::Packwerk::ConstNodeInspector.new,
        ::Packwerk::AssociationInspector.new(inflector: inflector, custom_associations: custom_associations),
      ]
    end

    def checkers
      @checkers ||= checker_classes.map(&:new)
    end

    def resolver
      @resolver ||= ConstantResolver.new(root_path: root_path, load_paths: load_paths, inflector: inflector)
    end
  end
end
