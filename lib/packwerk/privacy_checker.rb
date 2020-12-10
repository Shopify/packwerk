# typed: strict
# frozen_string_literal: true

require "packwerk/violation_type"
require "packwerk/checker"

module Packwerk
  class PrivacyChecker
    extend T::Sig
    include Checker

    sig { override.returns(Packwerk::ViolationType) }
    def violation_type
      ViolationType::Privacy
    end

    sig do
      override
        .params(reference: Packwerk::Reference, reference_lister: Packwerk::ReferenceLister)
        .returns(T::Boolean)
    end
    def invalid_reference?(reference, reference_lister)
      return false if reference.constant.public?

      privacy_option = reference.constant.package.enforce_privacy
      return false if enforcement_disabled?(privacy_option)

      return false unless privacy_option == true ||
        explicitly_private_constant?(reference.constant, explicitly_private_constants: privacy_option)

      return false if reference_lister.listed?(reference, violation_type: violation_type)

      true
    end

    sig { override.params(reference: Packwerk::Reference).returns(String) }
    def message_for(reference)
      source_desc = reference.source_package ? "'#{reference.source_package}'" : "here"
      "Privacy violation: '#{reference.constant.name}' is private to '#{reference.constant.package}' but " \
        "referenced from #{source_desc}.\n" \
        "Is there a public entrypoint in '#{reference.constant.package.public_path}' that you can use instead?"
    end

    private

    sig do
      params(
        constant: ConstantDiscovery::ConstantContext,
        explicitly_private_constants: T::Array[String]
      ).returns(T::Boolean)
    end
    def explicitly_private_constant?(constant, explicitly_private_constants:)
      explicitly_private_constants.include?(constant.name) ||
        # nested constants
        explicitly_private_constants.any? { |epc| constant.name.start_with?(epc + "::") }
    end

    sig do
      params(privacy_option: T.nilable(T.any(T::Boolean, T::Array[String])))
        .returns(T::Boolean)
    end
    def enforcement_disabled?(privacy_option)
      [false, nil].include?(privacy_option)
    end
  end
end
