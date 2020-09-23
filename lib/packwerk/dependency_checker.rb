# typed: true
# frozen_string_literal: true

require "packwerk/violation_type"

module Packwerk
  class DependencyChecker
    def violation_type
      ViolationType::Dependency
    end

    def invalid_reference?(reference, reference_lister)
      return unless reference.source_package
      return unless reference.source_package.enforce_dependencies?
      return if reference.source_package.dependency?(reference.constant.package)
      return if reference_lister.listed?(reference, violation_type: violation_type)
      true
    end

    def message_for(reference)
      "Dependency violation: #{reference.constant.name} belongs to '#{reference.constant.package}', but " \
        "'#{reference.source_package}' does not specify a dependency on " \
        "'#{reference.constant.package}'.\n" \
        "Are we missing an abstraction?\n" \
        "Is the code making the reference, and the referenced constant, in the right packages?\n"
    end
  end
end
