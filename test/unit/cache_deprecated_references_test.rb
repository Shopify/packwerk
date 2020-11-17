# typed: false
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class CacheDeprecatedReferencesTest < Minitest::Test
    setup do
      @updating_deprecated_references = CacheDeprecatedReferences.new(".")
    end

    test "#listed? adds entry and returns true" do
      File.stubs(:open)

      source_package = Package.new(name: "source_package", config: {})
      destination_package = Package.new(name: "destination_package", config: {})
      reference =
        Reference.new(
          source_package,
          "some/path.rb",
          ConstantDiscovery::ConstantContext.new(nil, nil, destination_package, false)
        )

      Packwerk::DeprecatedReferences.any_instance
        .expects(:add_entries)
        .with(reference, "dependency")

      assert @updating_deprecated_references.listed?(reference, violation_type: ViolationType::Dependency)
    end
  end
end
