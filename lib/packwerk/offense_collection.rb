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
      package_todo_for(reference.source_package).listed?(reference, violation_type: offense.violation_type)
    end

    sig do
      params(offense: Packwerk::Offense).void
    end
    def add_offense(offense)
      unless offense.is_a?(ReferenceOffense)
        @errors << offense
        return
      end
      package_todo = package_todo_for(offense.reference.source_package)
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

    sig { void }
    def dump_package_todo_files
      @package_todo.each do |_, package_todo_file|
        package_todo_file.dump
      end
    end

    sig { returns(T::Array[Packwerk::Offense]) }
    def outstanding_offenses
      errors + new_violations
    end

    private

    sig { params(package: Packwerk::Package).returns(Packwerk::PackageTodo) }
    def package_todo_for(package)
      @package_todo[package] ||= Packwerk::PackageTodo.new(
        package,
        package_todo_file_for(package),
      )
    end

    sig { params(package: Packwerk::Package).returns(String) }
    def package_todo_file_for(package)
      if Pathname.new(@root_path).join(package.name, "deprecated_references.yml").exist?
        warning = <<~WARNING.squish
          DEPRECATION WARNING: `deprecated_references.yml` files have been renamed to
          `package_todo.yml`. Please see https://github.com/Shopify/packwerk/releases
          for help renaming these.
        WARNING

        warn(warning)
        File.join(@root_path, package.name, "deprecated_references.yml")
      else
        File.join(@root_path, package.name, "package_todo.yml")
      end
    end
  end
end
