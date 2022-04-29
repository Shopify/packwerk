# typed: strict
# frozen_string_literal: true

module Packwerk
  class OffenseCollection
    extend T::Sig
    extend T::Helpers

    DepRefDictionary = T.type_alias { T::Hash[Packwerk::Package, Packwerk::DeprecatedReferences] }

    sig { params(run_context: RunContext).void }
    def initialize(run_context)
      @dep_refs_dictionary = T.let(build_deprecated_references(run_context), DepRefDictionary)
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

    sig { returns(T::Boolean) }
    def stale_violations?
      @dep_refs_dictionary.values.any?(&:stale_violations?)
    end

    sig { void }
    def dump_deprecated_references_files
      @dep_refs_dictionary.each do |_, deprecated_references_file|
        deprecated_references_file.dump
      end
    end

    sig { returns(T::Array[Packwerk::Offense]) }
    def outstanding_offenses
      errors + new_violations
    end

    private

    sig { params(run_context: Packwerk::RunContext).returns(DepRefDictionary) }
    def build_deprecated_references(run_context)
      run_context.package_set.each_with_object({}) do |package, deprecated_references|
        deprecated_references[package] = Packwerk::DeprecatedReferences.for(
          package: package,
          root_path: run_context.root_path
        )
      end
    end

    sig { params(package: Packwerk::Package).returns(Packwerk::DeprecatedReferences) }
    def deprecated_references_for(package)
      deprecated_references = @dep_refs_dictionary[package]
      raise Packwerk::Error, "Reference belongs to unknown package!" if deprecated_references.nil?

      deprecated_references
    end
  end
end
