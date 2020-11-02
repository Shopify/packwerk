# typed: true
# frozen_string_literal: true

require "sorbet-runtime"

require "packwerk/deprecated_references"
require "packwerk/reference"
require "packwerk/reference_lister"
require "packwerk/violation_type"

module Packwerk
  class CacheDeprecatedReferences
    extend T::Sig
    include ReferenceLister

    def initialize(root_path, deprecated_references = {})
      @root_path = root_path
      @deprecated_references = deprecated_references
    end

    sig do
      params(reference: Packwerk::Reference, violation_type: ViolationType)
        .returns(T::Boolean)
        .override
    end
    def listed?(reference, violation_type:)
      deprecated_references = deprecated_references_for(reference.source_package)
      deprecated_references.add_entries(reference, violation_type.serialize)
      true
    end

    private

    def deprecated_references_for(package)
      @deprecated_references[package] ||= Packwerk::DeprecatedReferences.new(
        package,
        deprecated_references_file_for(package),
      )
    end

    def deprecated_references_file_for(package)
      File.join(@root_path, package.name, "deprecated_references.yml")
    end
  end
end
