# typed: strict
# frozen_string_literal: true

require "packwerk/violation_type"
require "packwerk/checker"

module Packwerk
  class DependencyChecker
    extend T::Sig
    include Checker

    sig { override.returns(ViolationType) }
    def violation_type
      ViolationType::Dependency
    end

    sig do
      override
        .params(reference: Packwerk::Reference, reference_lister: Packwerk::ReferenceLister)
        .returns(T::Boolean)
    end
    def invalid_reference?(reference, reference_lister)
      return false unless reference.source_package
      return false unless reference.source_package.enforce_dependencies?
      return false if reference.source_package.dependency?(reference.constant.package)
      return false if reference_lister.listed?(reference, violation_type: violation_type)
      true
    end

    sig { override.params(reference: Packwerk::Reference).returns(String) }
    def message_for(reference)
      "Dependency violation: #{reference.constant.name} belongs to '#{reference.constant.package}', but " \
        "'#{reference.source_package}' does not specify a dependency on " \
        "'#{reference.constant.package}'.\n" \
        "Are we missing an abstraction?\n" \
        "Is the code making the reference, and the referenced constant, in the right packages?\n"
    end
  end
end
