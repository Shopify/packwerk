# typed: true
# frozen_string_literal: true

require "packwerk/violation_type"
require "packwerk/checker"

module Packwerk
  class PrivacyChecker
    include Checker

    def violation_type
      ViolationType::Privacy
    end

    def invalid_reference?(reference, reference_lister)
      return if reference.constant.public?

      privacy_option = reference.constant.package.enforce_privacy
      return if enforcement_disabled?(privacy_option)

      return unless privacy_option == true ||
        explicitly_private_constant?(reference.constant, explicitly_private_constants: privacy_option)

      return if reference_lister.listed?(reference, violation_type: violation_type)

      true
    end

    def message_for(reference)
      source_desc = reference.source_package ? "'#{reference.source_package}'" : "here"
      "Privacy violation: '#{reference.constant.name}' is private to '#{reference.constant.package}' but " \
        "referenced from #{source_desc}.\n" \
        "Is there a public entrypoint in '#{reference.constant.package.public_path}' that you can use instead?"
    end

    private

    def explicitly_private_constant?(constant, explicitly_private_constants:)
      explicitly_private_constants.include?(constant.name) ||
        # nested constants
        explicitly_private_constants.any? { |epc| constant.name.start_with?(epc + "::") }
    end

    def enforcement_disabled?(privacy_option)
      [false, nil].include?(privacy_option)
    end
  end
end
