# typed: false
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class CacheDeprecatedReferencesTest < Minitest::Test
    include FactoryHelper

    setup do
      @updating_deprecated_references = CacheDeprecatedReferences.new(".")
    end

    test "#listed? adds entry and returns true" do
      File.stubs(:open)
      reference = build_reference

      Packwerk::DeprecatedReferences.any_instance
        .expects(:add_entries)
        .with(reference, "dependency")

      assert @updating_deprecated_references.listed?(reference, violation_type: ViolationType::Dependency)
    end
  end
end
