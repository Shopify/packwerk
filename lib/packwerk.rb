# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require "active_support"
require "fileutils"

module Packwerk
  extend ActiveSupport::Autoload

  autoload :ApplicationLoadPaths
  autoload :ApplicationValidator
  autoload :AssociationInspector
  autoload :OffenseCollection
  autoload :Checker
  autoload :Cli
  autoload :Configuration
  autoload :ConstantDiscovery
  autoload :ConstantNameInspector
  autoload :ConstNodeInspector
  autoload :DependencyChecker
  autoload :DeprecatedReferences
  autoload :FileProcessor
  autoload :FilesForProcessing
  autoload :Graph
  autoload :Inflector
  autoload :Node
  autoload :NodeProcessor
  autoload :NodeProcessorFactory
  autoload :NodeVisitor
  autoload :Offense
  autoload :OutputStyle
  autoload :Package
  autoload :PackageSet
  autoload :ParsedConstantDefinitions
  autoload :Parsers
  autoload :ParseRun
  autoload :PrivacyChecker
  autoload :Reference
  autoload :ReferenceExtractor
  autoload :ReferenceOffense
  autoload :Result
  autoload :RunContext
  autoload :Version
  autoload :ViolationType

  module Inflections
    extend ActiveSupport::Autoload

    autoload :Custom
    autoload :Default
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

    autoload :OffensesFormatter
    autoload :ProgressFormatter
  end

  module Generators
    extend ActiveSupport::Autoload

    autoload :ApplicationValidation
    autoload :ConfigurationFile
    autoload :InflectionsFile
    autoload :RootPackage
  end
end
