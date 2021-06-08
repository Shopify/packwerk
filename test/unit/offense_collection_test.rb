# typed: false
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class OffenseCollectionTest < Minitest::Test
    include FactoryHelper

    setup do
      @offense_collection = OffenseCollection.new(".")
      reference = build_reference

      @offense = ReferenceOffense.new(reference: reference, violation_type: ViolationType::Dependency)
    end

    test "#add_violation adds entry and returns true" do
      File.stubs(:open)

      Packwerk::DeprecatedReferences.any_instance
        .expects(:add_entries)
        .with(@offense.reference, @offense.violation_type)

      @offense_collection.add_offense(@offense)
    end

    test "#stale_violations? returns true if there are stale violations" do
      @offense_collection.add_offense(@offense)

      Packwerk::DeprecatedReferences.any_instance
        .expects(:stale_violations?)
        .returns(true)

      assert @offense_collection.stale_violations?
    end

    test "#stale_violations? returns false if no stale violations" do
      @offense_collection.add_offense(@offense)

      Packwerk::DeprecatedReferences.any_instance
        .expects(:stale_violations?)
        .returns(false)

      refute @offense_collection.stale_violations?
    end

    test "#listed? returns true if constant is listed in file" do
      package = Package.new(name: "buyer", config: {})
      reference = build_reference(source_package: package)
      deprecated_references = Packwerk::DeprecatedReferences.new(package, ".")
      deprecated_references
        .stubs(:listed?)
        .with(reference, violation_type: Packwerk::ViolationType::Dependency)
        .returns(true)
      Packwerk::DeprecatedReferences
        .stubs(:new)
        .with(package, "./buyer/deprecated_references.yml")
        .returns(deprecated_references)

      offense = Packwerk::ReferenceOffense.new(reference: reference, violation_type: ViolationType::Dependency)
      assert @offense_collection.listed?(offense)
    end

    test "#listed? returns false if constant is not listed in file " do
      offense = Packwerk::ReferenceOffense.new(reference: build_reference, violation_type: ViolationType::Dependency)
      refute @offense_collection.listed?(offense)
    end
  end
end
