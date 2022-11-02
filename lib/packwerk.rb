# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require "active_support"
require "fileutils"

# Provides String#pluralize
require "active_support/core_ext/string"

module Packwerk
  extend ActiveSupport::Autoload

  autoload :ApplicationLoadPaths
  autoload :ApplicationValidator
  autoload :AssociationInspector
  autoload :OffenseCollection
  autoload :Cache
  autoload :Cli
  autoload :Configuration
  autoload :ConstantDiscovery
  autoload :ConstantNameInspector
  autoload :ConstNodeInspector
  autoload :PackageTodo
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
  autoload :Offense
  autoload :OffensesFormatter
  autoload :OutputStyle
  autoload :Package
  autoload :PackageSet
  autoload :ParsedConstantDefinitions
  autoload :Parsers
  autoload :ParseRun
  autoload :UnresolvedReference
  autoload :Reference
  autoload :ReferenceExtractor
  autoload :ReferenceOffense
  autoload :Result
  autoload :RunContext
  autoload :Version

  module OutputStyles
    extend ActiveSupport::Autoload

    autoload :Coloured
    autoload :Plain
  end

  autoload_under "commands" do
    autoload :OffenseProgressMarker
  end

  module Formatters
    extend ActiveSupport::Autoload

    autoload :OffensesFormatter
    autoload :ProgressFormatter
  end

  module Generators
    extend ActiveSupport::Autoload

    autoload :ConfigurationFile
    autoload :RootPackage
  end

  module ReferenceChecking
    extend ActiveSupport::Autoload

    autoload :ReferenceChecker

    module Checkers
      extend ActiveSupport::Autoload

      autoload :Checker

      autoload :DependencyChecker
      autoload :PrivacyChecker
    end
  end

  class ApplicationValidator
    extend ActiveSupport::Autoload

    autoload :Result
    autoload :CheckPackageManifestsForPrivacy
    autoload :Helpers
  end
end
