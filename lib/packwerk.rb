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

  autoload :ApplicationLoadPaths
  autoload :ApplicationValidator
  autoload :AssociationInspector
  autoload :OffenseCollection
  autoload :Cache
  autoload :Checker
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
  autoload :Validator
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

    autoload :ProgressFormatter
  end

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

  class ApplicationValidator
    extend ActiveSupport::Autoload

    autoload :Result
    autoload :Helpers
  end
end

# Required to register the default OffensesFormatter
# We put this at the *end* of the file to specify all autoloads first
require "packwerk/formatters/offenses_formatter"

# Required to register the default DependencyChecker
require "packwerk/reference_checking/checkers/dependency_checker"
# Required to register the default DependencyValidator
require "packwerk/validators/dependency_validator"
