# typed: strict
# frozen_string_literal: true

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
        .params(reference: Packwerk::Reference)
        .returns(T::Boolean)
    end
    def invalid_reference?(reference)
      return false unless reference.source_package
      return false unless reference.source_package.enforce_dependencies?
      return false if reference.source_package.dependency?(reference.constant.package)
      true
    end
  end
end
