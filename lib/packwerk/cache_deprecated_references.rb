# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

require "packwerk/deprecated_references"
require "packwerk/reference"
require "packwerk/violation_type"

module Packwerk
  class CacheDeprecatedReferences
    extend T::Sig
    extend T::Helpers
    abstract!

    sig do
      params(
        root_path: String,
        deprecated_references: T::Hash[Packwerk::Package, Packwerk::DeprecatedReferences]
      ).void
    end
    def initialize(root_path, deprecated_references = {})
      @root_path = root_path
      @deprecated_references = T.let(deprecated_references, T::Hash[Packwerk::Package, Packwerk::DeprecatedReferences])
    end

    sig do
      params(reference_offense: Packwerk::ReferenceOffense).void
    end
    def add_offense(reference_offense)
      deprecated_references = deprecated_references_for(reference_offense.reference.source_package)
      deprecated_references.add_entries(reference_offense)
    end

    def dump_deprecated_references_files
      @deprecated_references.each do |_, deprecated_references_file|
        deprecated_references_file.dump
      end
    end

    sig { returns(T::Boolean) }
    def stale_violations?
      @deprecated_references.values.any?(&:stale_violations?)
    end

    sig { returns(T::Boolean) }
    def new_offenses?
      @deprecated_references.values.any?(&:new_offenses?)
    end

    sig do
      params(offense: Packwerk::ReferenceOffense)
        .returns(T::Boolean)
    end
    def listed?(offense)
      deprecated_references = deprecated_references_for(offense.reference.source_package)
      deprecated_references.listed?(offense)
    end

    private

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
