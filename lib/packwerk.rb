# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require "active_support"
require "fileutils"

# Provides String#pluralize
require "active_support/core_ext/string"
# Provides Object#to_json
require "active_support/core_ext/object/json"

module Packwerk
  extend ActiveSupport::Autoload

  # Public APIs
  autoload :Checker
  autoload :Cli
  autoload :Offense
  autoload :OffensesFormatter
  autoload :OutputStyle
  autoload :Package
  autoload :PackageSet
  autoload :PackageTodo
  autoload :Parsers
  autoload :Reference
  autoload :ReferenceOffense
  autoload :Validator

  # Private APIs
  # Please submit an issue if you have a use-case for these
  autoload :ApplicationLoadPaths
  private_constant :ApplicationLoadPaths
  autoload :ApplicationValidator
  private_constant :ApplicationValidator
  autoload :AssociationInspector
  private_constant :AssociationInspector
  autoload :Cache
  private_constant :Cache
  autoload :Configuration
  private_constant :Configuration
  autoload :ConstantDiscovery
  private_constant :ConstantDiscovery
  autoload :ConstantNameInspector
  private_constant :ConstantNameInspector
  autoload :ConstNodeInspector
  private_constant :ConstNodeInspector
  autoload :ExtensionLoader
  private_constant :ExtensionLoader
  autoload :FileProcessor
  private_constant :FileProcessor
  autoload :FilesForProcessing
  private_constant :FilesForProcessing
  autoload :Graph
  private_constant :Graph
  autoload :Loader
  private_constant :Loader
  autoload :Node
  private_constant :Node
  autoload :NodeHelpers
  private_constant :NodeHelpers
  autoload :NodeProcessor
  private_constant :NodeProcessor
  autoload :NodeProcessorFactory
  private_constant :NodeProcessorFactory
  autoload :NodeVisitor
  private_constant :NodeVisitor
  autoload :OffenseCollection
  private_constant :OffenseCollection
  autoload :ParsedConstantDefinitions
  private_constant :ParsedConstantDefinitions
  autoload :ParseRun
  private_constant :ParseRun
  autoload :ReferenceExtractor
  private_constant :ReferenceExtractor
  autoload :RunContext
  private_constant :RunContext
  autoload :UnresolvedReference
  private_constant :UnresolvedReference
  autoload :Version
  private_constant :Version

  module Validator
    extend ActiveSupport::Autoload

    autoload :Result
  end

  class Cli
    extend ActiveSupport::Autoload

    autoload :Result
  end

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

  class ApplicationValidator
    extend ActiveSupport::Autoload

    autoload :Helpers
  end
end

# Required to register the DefaultOffensesFormatter
# We put this at the *end* of the file to specify all autoloads first
require "packwerk/formatters/default_offenses_formatter"

# Required to register the default DependencyChecker
require "packwerk/reference_checking/checkers/dependency_checker"
# Required to register the default DependencyValidator
require "packwerk/validators/dependency_validator"
