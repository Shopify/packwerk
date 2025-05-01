# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class ReferenceOffenseTest < Minitest::Test
    include FactoryHelper

    setup do
      destination_package = Package.new(name: "destination_package", config: {})
      @reference = build_reference(destination_package: destination_package)
    end

    test "has its file attribute set to the relative path of the reference" do
      offense = ReferenceOffense.new(
        reference: @reference,
        message: "some message",
        violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE
      )

      assert_equal(@reference.relative_path, offense.file)
    end

    test "generates a sensible message for dependency violations" do
      message = ReferenceChecking::Checkers::DependencyChecker.new.message(@reference)
      offense = ReferenceOffense.new(reference: @reference, message: message,
        violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE)

      expected = <<~EXPECTED
        Dependency violation: ::SomeName belongs to 'destination_package', but 'components/source' does not specify a dependency on 'destination_package'.
        Are the constant and its references in the right packages?

        Inference details: this is a reference to ::SomeName which seems to be defined in some/location.rb.
        To receive help interpreting or resolving this error message, see: https://github.com/Shopify/packwerk/blob/main/TROUBLESHOOT.md#Troubleshooting-violations
      EXPECTED

      assert_equal(expected, offense.message)
    end
  end
end
