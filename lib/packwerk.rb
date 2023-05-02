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
  autoload :Configuration
  autoload :ConstantContext
  autoload :Node
  autoload :Offense
  autoload :OffenseCollection
  autoload :OffensesFormatter
  autoload :OutputStyle
  autoload :Package
  autoload :PackageSet
  autoload :PackageTodo
  autoload :Parsers
  autoload :RailsLoadPaths
  autoload :Reference
  autoload :ReferenceOffense
  autoload :Validator

  module OutputStyles
    extend ActiveSupport::Autoload

    autoload :Coloured
    autoload :Plain
  end

  module Formatters
    extend ActiveSupport::Autoload

    autoload :DefaultOffensesFormatter
    autoload :ProgressFormatter
  end

  module Validators
    extend ActiveSupport::Autoload

    autoload :DependencyValidator
  end

  # Private APIs
  # Please submit an issue if you have a use-case for these
  autoload :ApplicationValidator
  autoload :AssociationInspector
  autoload :Cache
  autoload :ConstantDiscovery
  autoload :ConstantNameInspector
  autoload :ConstNodeInspector
  autoload :ExtensionLoader
  autoload :FileProcessor
  autoload :FilesForProcessing
  autoload :Graph
  autoload :NodeHelpers
  autoload :NodeProcessor
  autoload :NodeProcessorFactory
  autoload :NodeVisitor
  autoload :ParsedConstantDefinitions
  autoload :ParseRun
  autoload :ReferenceExtractor
  autoload :RunContext
  autoload :UnresolvedReference

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
    end
  end

  private_constant :ReferenceChecking

  Cli.register_command("init", help: "set up packwerk")
  Cli.register_command("check", help: "run all checks")
  Cli.register_command("update-todo", aliases: ["update"], help: "update package_todo.yml files")
  Cli.register_command("validate", help: "verify integrity of packwerk and package configuration")
  Cli.register_command("version", help: "output packwerk version")
  Cli.register_command("help", help: "display help information about packwerk")
end

require "packwerk/version"
