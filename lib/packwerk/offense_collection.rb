# typed: strict
# frozen_string_literal: true

module Packwerk
  class OffenseCollection
    extend T::Sig
    extend T::Helpers

    sig do
      params(
        root_path: String,
        deprecated_references: T::Hash[Packwerk::Package, Packwerk::DeprecatedReferences]
      ).void
    end
    def initialize(root_path, deprecated_references = {})
      @root_path = root_path
      @deprecated_references = T.let(deprecated_references, T::Hash[Packwerk::Package, Packwerk::DeprecatedReferences])
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
      deprecated_references_for(reference.source_package).listed?(reference, violation_type: offense.violation_type)
    end

    sig do
      params(offense: Packwerk::Offense).void
    end
    def add_offense(offense)
      unless offense.is_a?(ReferenceOffense)
        @errors << offense
        return
      end
      deprecated_references = deprecated_references_for(offense.reference.source_package)
      unless deprecated_references.add_entries(offense.reference, offense.violation_type)
        new_violations << offense
      end
    end

    sig { params(for_files: T::Set[String]).returns(T::Boolean) }
    def stale_violations?(for_files)
      @deprecated_references.values.any? do |deprecated_references|
        deprecated_references.stale_violations?(for_files)
      end
    end

    sig { params(package_set: Packwerk::PackageSet).void }
    def persist_deprecated_references_files(package_set)
      dump_deprecated_references_files
      cleanup_extra_deprecated_references_files(package_set)
    end

    sig { returns(T::Array[Packwerk::Offense]) }
    def outstanding_offenses
      errors + new_violations
    end

    private

    sig { params(package_set: Packwerk::PackageSet).void }
    def cleanup_extra_deprecated_references_files(package_set)
      packages_without_todos = (package_set.packages.values - @deprecated_references.keys)

      packages_without_todos.each do |package|
        Packwerk::DeprecatedReferences.new(
          package,
          deprecated_references_file_for(package),
        ).delete_if_exists
      end
    end

    sig { void }
    def dump_deprecated_references_files
      @deprecated_references.each_value(&:dump)
    end

    sig { params(package: Packwerk::Package).returns(Packwerk::DeprecatedReferences) }
    def deprecated_references_for(package)
      @deprecated_references[package] ||= Packwerk::DeprecatedReferences.new(
        package,
        deprecated_references_file_for(package),
      )
    end

    sig { params(package: Packwerk::Package).returns(String) }
    def deprecated_references_file_for(package)
      File.join(@root_path, package.name, "deprecated_references.yml")
    end
  end
end
