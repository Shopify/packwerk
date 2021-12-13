# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require "active_support"
require "fileutils"
require 'open3'
require 'json'

# Provides String#pluralize
require "active_support/core_ext/string"
require 'packwerk/diagnostics'
Packwerk::Diagnostics.log('Requiring railtie if Rails is defined', __FILE__)
require 'packwerk/railtie' if defined?(Rails)

module Packwerk
  extend ActiveSupport::Autoload

  autoload :ApplicationValidator
  autoload :AssociationInspector
  autoload :Inflector
  autoload :OffenseCollection
  autoload :Cli
  autoload :Configuration
  autoload :ConstantDiscovery
  autoload :ConstantNameInspector
  autoload :ConstNodeInspector
  autoload :DeprecatedReferences
  autoload :FileProcessor
  autoload :FilesForProcessing
  autoload :Graph
  autoload :Node
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
  autoload :RailsDependencies
  autoload :Reference
  autoload :ReferenceExtractor
  autoload :ReferenceOffense
  autoload :Result
  autoload :RunContext
  autoload :Version
  autoload :ViolationType

  module OutputStyles
    extend ActiveSupport::Autoload

    autoload :Coloured
    autoload :Plain
  end

  module RailsDependencies
    extend ActiveSupport::Autoload

    autoload :Dump
    autoload :ApplicationLoadPaths
    autoload :Load
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
end
