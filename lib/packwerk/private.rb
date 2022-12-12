# typed: strict
# frozen_string_literal: true

module Packwerk
  # Private APIs
  # Please submit an issue if you have a use-case for these

  module Private
    extend ActiveSupport::Autoload

    autoload :ApplicationLoadPaths
    autoload :ApplicationValidator
    autoload :AssociationInspector
    autoload :Cache
    autoload :Configuration
    autoload :ConstantDiscovery
    autoload :ConstantNameInspector
    autoload :ConstNodeInspector
    autoload :ExtensionLoader
    autoload :FileProcessor
    autoload :FilesForProcessing
    autoload :Graph
    autoload :Loader
    autoload :Node
    autoload :NodeHelpers
    autoload :NodeProcessor
    autoload :NodeProcessorFactory
    autoload :NodeVisitor
    autoload :OffenseCollection
    autoload :ParsedConstantDefinitions
    autoload :ParseRun
    autoload :ReferenceExtractor
    autoload :RunContext
    autoload :UnresolvedReference
    autoload :Version

    module Formatters
      extend ActiveSupport::Autoload

      autoload :ProgressFormatter
    end

    private_constant :Formatters

    module Generators
      extend ActiveSupport::Autoload

      autoload :ConfigurationFile
      autoload :RootPackage
    end

    private_constant :Generators

    module ReferenceChecking
      extend ActiveSupport::Autoload

      autoload :ReferenceChecker

      module Checkers
        extend ActiveSupport::Autoload

        autoload :DependencyChecker
        autoload :PrivacyChecker
      end
    end

    private_constant :ReferenceChecking
  end

  private_constant :Private
end
