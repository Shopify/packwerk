# typed: strict
# frozen_string_literal: true

require "pathname"

module Packwerk
  class OffenseCollection
    extend T::Sig
    extend T::Helpers

    #: (String root_path, ?Hash[Packwerk::Package, Packwerk::PackageTodo] package_todos) -> void
    def initialize(root_path, package_todos = {})
      @root_path = root_path
      @package_todos = package_todos #: Hash[Packwerk::Package, Packwerk::PackageTodo]
      @new_violations = [] #: Array[Packwerk::ReferenceOffense]
      @strict_mode_violations = [] #: Array[Packwerk::ReferenceOffense]
      @errors = [] #: Array[Packwerk::Offense]
    end

    #: Array[Packwerk::ReferenceOffense]
    attr_reader :new_violations

    #: Array[Packwerk::Offense]
    attr_reader :errors

    #: Array[Packwerk::ReferenceOffense]
    attr_reader :strict_mode_violations

    #: (Packwerk::Offense offense) -> bool
    def listed?(offense)
      return false unless offense.is_a?(ReferenceOffense)

      already_listed?(offense)
    end

    #: (Array[Offense] offenses) -> void
    def add_offenses(offenses)
      offenses.each { |offense| add_offense(offense) }
    end

    #: (Packwerk::Offense offense) -> void
    def add_offense(offense)
      unless offense.is_a?(ReferenceOffense)
        @errors << offense
        return
      end

      already_listed = already_listed?(offense)

      new_violations << offense unless already_listed

      if strict_mode_violation?(offense)
        add_to_package_todo(offense) if already_listed
        strict_mode_violations << offense
      else
        add_to_package_todo(offense)
      end
    end

    #: (Set[String] for_files) -> bool
    def stale_violations?(for_files)
      @package_todos.values.any? do |package_todo|
        package_todo.stale_violations?(for_files)
      end
    end

    #: (Packwerk::PackageSet package_set) -> void
    def persist_package_todo_files(package_set)
      dump_package_todo_files
      cleanup_extra_package_todo_files(package_set)
    end

    #: -> Array[Packwerk::Offense]
    def outstanding_offenses
      errors + new_violations
    end

    #: -> Array[Packwerk::ReferenceOffense]
    def unlisted_strict_mode_violations
      strict_mode_violations.reject { |offense| already_listed?(offense) }
    end

    private

    #: (ReferenceOffense offense) -> bool
    def already_listed?(offense)
      package_todo_for(offense.reference.package).listed?(offense.reference,
        violation_type: offense.violation_type)
    end

    #: (ReferenceOffense offense) -> bool
    def add_to_package_todo(offense)
      package_todo_for(offense.reference.package).add_entries(offense.reference,
        offense.violation_type)
    end

    #: (ReferenceOffense offense) -> bool
    def strict_mode_violation?(offense)
      checker = Checker.find(offense.violation_type)
      checker.strict_mode_violation?(offense)
    end

    #: (Packwerk::PackageSet package_set) -> void
    def cleanup_extra_package_todo_files(package_set)
      packages_without_todos = (package_set.packages.values - @package_todos.keys)

      packages_without_todos.each do |package|
        Packwerk::PackageTodo.new(
          package,
          package_todo_file_for(package),
        ).delete_if_exists
      end
    end

    #: -> void
    def dump_package_todo_files
      @package_todos.each_value(&:dump)
    end

    #: (Packwerk::Package package) -> Packwerk::PackageTodo
    def package_todo_for(package)
      @package_todos[package] ||= Packwerk::PackageTodo.new(
        package,
        package_todo_file_for(package),
      )
    end

    #: (Packwerk::Package package) -> String
    def package_todo_file_for(package)
      File.join(@root_path, package.name, "package_todo.yml")
    end
  end
end
