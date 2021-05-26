# typed: strict
# frozen_string_literal: true

module Packwerk
  class CheckingDeprecatedReferences
    extend T::Sig
    include ReferenceLister

    sig { params(root_path: String).void }
    def initialize(root_path)
      @root_path = root_path
      @deprecated_references = T.let({}, T::Hash[Packwerk::Package, Packwerk::DeprecatedReferences])
    end

    sig do
      params(reference: Packwerk::Reference, violation_type: ViolationType)
        .returns(T::Boolean)
        .override
    end
    def listed?(reference, violation_type:)
      deprecated_references_for(reference.source_package).listed?(reference, violation_type: violation_type)
    end

    private

    sig { params(source_package: Packwerk::Package).returns(Packwerk::DeprecatedReferences) }
    def deprecated_references_for(source_package)
      @deprecated_references[source_package] ||= Packwerk::DeprecatedReferences.new(
        source_package,
        deprecated_references_file_for(source_package),
      )
    end

    sig { params(package: Packwerk::Package).returns(String) }
    def deprecated_references_file_for(package)
      File.join(@root_path, package.name, "deprecated_references.yml")
    end
  end
end
