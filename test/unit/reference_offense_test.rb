# typed: ignore
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class ReferenceOffenseTest < Minitest::Test
    include FactoryHelper

    setup do
      destination_package = Package.new(name: "destination_package", config: { "enforce_privacy" => true })
      @reference = build_reference(destination_package: destination_package)
    end

    test "has its file attribute set to the relative path of the reference" do
      offense = ReferenceOffense.new(reference: @reference, violation_type: ViolationType::Privacy)
      assert_equal(@reference.relative_path, offense.file)
    end

    test "generates a sensible message for privacy violations" do
      offense = ReferenceOffense.new(reference: @reference, violation_type: ViolationType::Privacy)

      assert_match(
        "Privacy violation: '::SomeName' is private to 'destination_package' but referenced from " \
          "'components/source'.", offense.message
      )
    end

    test "generates a sensible message for dependency violations" do
      offense = ReferenceOffense.new(reference: @reference, violation_type: ViolationType::Dependency)

      expected = <<~EXPECTED
        Dependency violation: ::SomeName belongs to 'destination_package', but 'components/source' does not specify a dependency on 'destination_package'.
        Are we missing an abstraction?
        Is the code making the reference, and the referenced constant, in the right packages?

        Inference details: this is a reference to ::SomeName which seems to be defined in some/location.rb.
        To receive help interpreting or resolving this error message, see: https://github.com/Shopify/packwerk/blob/main/TROUBLESHOOT.md#Troubleshooting-violations
      EXPECTED

      assert_equal(expected, offense.message)
    end
  end
end
