# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class OffenseCollectionTest < Minitest::Test
    include FactoryHelper
    include TypedMock

    setup do
      @offense = ReferenceOffense.new(reference: build_reference, violation_type: ViolationType::Dependency)
      @run_context = typed_mock
      @run_context.stubs(:package_set).returns(Packwerk::PackageSet.new([@offense.reference.source_package]))
      @run_context.stubs(:root_path).returns(".")
      @offense_collection = OffenseCollection.new(@run_context)
    end

    test "#add_violation adds entry and returns true" do
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

      assert_predicate @offense_collection, :stale_violations?
    end

    test "#stale_violations? returns false if no stale violations" do
      @offense_collection.add_offense(@offense)

      Packwerk::DeprecatedReferences.any_instance
        .expects(:stale_violations?)
        .returns(false)

      refute_predicate @offense_collection, :stale_violations?
    end

    test "#listed? returns true if constant is listed in file" do
      package = @offense.reference.source_package
      reference = build_reference(source_package: package)
      deprecated_references = Packwerk::DeprecatedReferences.new(package, ".")
      deprecated_references
        .stubs(:listed?)
        .with(reference, violation_type: Packwerk::ViolationType::Dependency)
        .returns(true)
      Packwerk::DeprecatedReferences.stubs(:for).returns(deprecated_references)

      # reinstantiate so that above stubs take effect
      offense_collection = OffenseCollection.new(@run_context)
      offense = Packwerk::ReferenceOffense.new(reference: reference, violation_type: ViolationType::Dependency)

      assert offense_collection.listed?(offense)
    end

    test "#listed? returns false if constant is not listed in file " do
      offense = Packwerk::ReferenceOffense.new(reference: build_reference, violation_type: ViolationType::Dependency)
      refute @offense_collection.listed?(offense)
    end
  end
end
