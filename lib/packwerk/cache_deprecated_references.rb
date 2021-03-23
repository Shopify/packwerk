# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

require "packwerk/deprecated_references"
require "packwerk/reference"
require "packwerk/reference_lister"
require "packwerk/violation_type"

module Packwerk
  class CacheDeprecatedReferences
    extend T::Sig
    extend T::Helpers
    include ReferenceLister
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
      params(reference: Packwerk::Reference, violation_type: ViolationType)
        .returns(T::Boolean)
        .override
    end
    def listed?(reference, violation_type:)
      false
    end

    def add_offense(offense)
      deprecated_references = deprecated_references_for(offense.reference.source_package)
      deprecated_references.add_entries(offense.reference, offense.violation_type.serialize)
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
