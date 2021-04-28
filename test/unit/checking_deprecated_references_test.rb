# typed: false
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class CheckingDeprecatedReferencesTest < Minitest::Test
    include FactoryHelper

    setup do
      @checking_deprecated_references = CheckingDeprecatedReferences.new(".")
      @package = Package.new(name: "buyer", config: {})
    end

    test "#listed? returns true if constant is listed in file" do
      reference = build_reference(source_package: @package)
      deprecated_references = Packwerk::DeprecatedReferences.new(@package, ".")
      deprecated_references
        .stubs(:listed?)
        .with(reference, violation_type: Packwerk::ViolationType::Dependency)
        .returns(true)
      Packwerk::DeprecatedReferences
        .stubs(:new)
        .with(@package, "./buyer/deprecated_references.yml")
        .returns(deprecated_references)

      assert @checking_deprecated_references.listed?(reference, violation_type: ViolationType::Dependency)
    end

    test "#listed? returns false if constant is not listed in file " do
      reference = build_reference(source_package: @package)
      refute @checking_deprecated_references.listed?(reference, violation_type: ViolationType::Dependency)
    end
  end
end
