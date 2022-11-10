# typed: strict
# frozen_string_literal: true

require "pathname"

module Packwerk
  class OffenseCollection
    extend T::Sig
    extend T::Helpers

    sig do
      params(
        root_path: String,
        package_todo: T::Hash[Packwerk::Package, Packwerk::PackageTodo]
      ).void
    end
    def initialize(root_path, package_todo = {})
      @root_path = root_path
      @package_todo = T.let(package_todo, T::Hash[Packwerk::Package, Packwerk::PackageTodo])
      @new_violations = T.let([], T::Array[Packwerk::ReferenceOffense])
      @errors = T.let([], T::Array[Packwerk::Offense])
    end

    sig { returns(T::Array[Packwerk::ReferenceOffense]) }
    attr_reader :new_violations

    sig { returns(T::Array[Packwerk::Offense]) }
    attr_reader :errors

    sig do
      params(offense: Packwerk::Offense)
        .returns(T::Boolean)
    end
    def listed?(offense)
      return false unless offense.is_a?(ReferenceOffense)

      reference = offense.reference
      checker = Checker.find(offense.violation_type)
      package_name_where_violation_should_live = checker.todo_file_for(reference)
      package_todo_for(package_name_where_violation_should_live).listed?(reference,
        violation_type: offense.violation_type)
    end

    sig do
      params(offense: Packwerk::Offense).void
    end
    def add_offense(offense)
      unless offense.is_a?(ReferenceOffense)
        @errors << offense
        return
      end
      checker = Checker.find(offense.violation_type)
      package_name_where_violation_should_live = checker.todo_file_for(offense.reference)
      package_todo = package_todo_for(package_name_where_violation_should_live)
      unless package_todo.add_entries(offense.reference, offense.violation_type)
        new_violations << offense
      end
    end

    sig { params(for_files: T::Set[String]).returns(T::Boolean) }
    def stale_violations?(for_files)
      @package_todo.values.any? do |package_todo|
        package_todo.stale_violations?(for_files)
      end
    end

    sig { params(package_set: Packwerk::PackageSet).void }
    def persist_package_todo_files(package_set)
      dump_package_todo_files
      cleanup_extra_package_todo_files(package_set)
    end

    sig { returns(T::Array[Packwerk::Offense]) }
    def outstanding_offenses
      errors + new_violations
    end

    private

    sig { params(package_set: Packwerk::PackageSet).void }
    def cleanup_extra_package_todo_files(package_set)
      packages_without_todos = (package_set.packages.values - @package_todo.keys)

      packages_without_todos.each do |package|
        Packwerk::PackageTodo.new(
          package,
          package_todo_file_for(package),
        ).delete_if_exists
      end
    end

    sig { void }
    def dump_package_todo_files
      @package_todo.each_value(&:dump)
    end

    sig { params(package: Packwerk::Package).returns(Packwerk::PackageTodo) }
    def package_todo_for(package)
      @package_todo[package] ||= Packwerk::PackageTodo.new(
        package,
        package_todo_file_for(package),
      )
    end

    sig { params(package: Packwerk::Package).returns(String) }
    def package_todo_file_for(package)
      File.join(@root_path, package.name, "package_todo.yml")
    end
  end
end
