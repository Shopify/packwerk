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
    autoload :ConstantDiscovery
    autoload :ConstantNameInspector
    autoload :ConstNodeInspector
    autoload :ExtensionLoader
    autoload :FileProcessor
    autoload :FilesForProcessing
    autoload :Node
    autoload :NodeHelpers
    autoload :NodeProcessor
    autoload :NodeProcessorFactory
    autoload :NodeVisitor
    autoload :ParsedConstantDefinitions
    autoload :ParseRun
    autoload :ReferenceExtractor
    autoload :RunContext
    autoload :UnresolvedReference

    class ApplicationValidator
      extend ActiveSupport::Autoload

      autoload :Helpers
    end
  end

  private_constant :Private
end
