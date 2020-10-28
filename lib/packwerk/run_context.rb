# typed: true
# frozen_string_literal: true

require "active_support/inflector"
require "constant_resolver"

require "packwerk/association_inspector"
require "packwerk/checking_deprecated_references"
require "packwerk/constant_discovery"
require "packwerk/const_node_inspector"
require "packwerk/fixture_reference_inspector"
require "packwerk/dependency_checker"
require "packwerk/file_processor"
require "packwerk/node_processor"
require "packwerk/package_set"
require "packwerk/privacy_checker"
require "packwerk/reference_extractor"

module Packwerk
  class RunContext
    attr_reader(
      :checkers,
      :constant_name_inspectors,
      :context_provider,
      :root_path,
      :file_processor,
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
        new(
          root_path: configuration.root_path,
          load_paths: configuration.load_paths,
          package_paths: configuration.package_paths,
          fixture_paths: configuration.fixture_paths,
          inflector: ActiveSupport::Inflector,
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
      fixture_paths:,
      custom_associations: [],
      checker_classes: DEFAULT_CHECKERS,
      node_processor_class: NodeProcessor,
      reference_lister: nil
    )
      @root_path = File.expand_path(root_path)

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
        ::Packwerk::FixtureReferenceInspector.new(root_path: root_path, fixture_paths: fixture_paths),
      ]

      @node_processor_class = node_processor_class
      @file_processor = FileProcessor.new(run_context: self)
    end

    def node_processor_for(filename:, ast_node:)
      reference_extractor = ::Packwerk::ReferenceExtractor.new(
        context_provider: context_provider,
        constant_name_inspectors: constant_name_inspectors,
        root_node: ast_node,
        root_path: root_path,
      )

      node_processor_class.new(
        reference_extractor: reference_extractor,
        reference_lister: @reference_lister,
        filename: filename,
        checkers: checkers,
      )
    end
  end
end
