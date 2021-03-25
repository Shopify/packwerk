# typed: ignore
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class ReferenceOffenseTest < Minitest::Test
    test "generates a sensible message for privacy violations" do
      destination_package = Package.new(name: "destination_package", config: { "enforce_privacy" => true })
      source_package = Package.new(name: "source_package", config: nil)

      reference =
        Reference.new(
          source_package,
          "some/path.rb",
          ConstantDiscovery::ConstantContext.new(
            "::SomeName",
            "some/location.rb",
            destination_package,
            false
          )
        )
      offense = ReferenceOffense.new(reference: reference, violation_type: ViolationType::Privacy)

      assert_match(
        "Privacy violation: '::SomeName' is private to 'destination_package' but referenced from " \
          "'source_package'.", offense.message
      )
    end

    test "generates a sensible message for dependency violations" do
      destination_package = Package.new(name: "destination_package", config: { "enforce_privacy" => true })
      source_package = Package.new(name: "source_package", config: nil)

      reference =
        Reference.new(
          source_package,
          "some/path.rb",
          ConstantDiscovery::ConstantContext.new(
            "::SomeName",
            "some/location.rb",
            destination_package,
            false
          )
        )
      offense = ReferenceOffense.new(reference: reference, violation_type: ViolationType::Dependency)

      expected = <<~EXPECTED
        Dependency violation: ::SomeName belongs to 'destination_package', but 'source_package' does not specify a dependency on 'destination_package'.
        Are we missing an abstraction?
        Is the code making the reference, and the referenced constant, in the right packages?

        Inference details: this is a reference to ::SomeName which seems to be defined in some/location.rb.
        To receive help interpreting or resolving this error message, see: https://github.com/Shopify/packwerk/blob/main/TROUBLESHOOT.md#Troubleshooting-violations
      EXPECTED

      assert_equal(expected, offense.message)
    end
  end
end
