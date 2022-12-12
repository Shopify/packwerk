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
  autoload :Graph
  autoload :Offense
  autoload :OffenseCollection
  autoload :OffensesFormatter
  autoload :OutputStyle
  autoload :Package
  autoload :PackageSet
  autoload :PackageTodo
  autoload :Parsers
  autoload :Reference
  autoload :ReferenceOffense
  autoload :Validator
  autoload :Version

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

      autoload :DependencyChecker
    end
  end

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

  # Private APIs
  autoload :Private
end

# Required to register the DefaultOffensesFormatter
# We put this at the *end* of the file to specify all autoloads first
require "packwerk/formatters/default_offenses_formatter"

# Required to register the default DependencyChecker
require "packwerk/reference_checking/checkers/dependency_checker"
# Required to register the default DependencyValidator
require "packwerk/validators/dependency_validator"
