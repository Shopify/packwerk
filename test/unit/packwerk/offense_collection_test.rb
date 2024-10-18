# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class OffenseCollectionTest < Minitest::Test
    include FactoryHelper

    setup do
      @offense_collection = OffenseCollection.new(".")
      @offense = ReferenceOffense.new(
        reference: build_reference,
        violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE,
        message: "some message"
      )
    end

    test "#add_violation adds entry and returns true" do
      Packwerk::PackageTodo.any_instance
        .expects(:add_entries)
        .with(@offense.reference, @offense.violation_type)
        .returns(true)

      @offense_collection.add_offense(@offense)
    end

    test "#stale_violations? returns true if there are stale violations" do
      @offense_collection.add_offense(@offense)
      file_set = Set.new
      FilesForProcessing.any_instance.stubs(:files).returns(file_set)
      files_for_processing = build_files_for_processing

      Packwerk::PackageTodo.any_instance
        .expects(:stale_violations?)
        .with(files_for_processing)
        .returns(true)

      assert @offense_collection.stale_violations?(files_for_processing)
    end

    test "#stale_violations? returns false if no stale violations" do
      @offense_collection.add_offense(@offense)
      file_set = Set.new
      FilesForProcessing.any_instance.stubs(:files).returns(file_set)
      files_for_processing = build_files_for_processing

      Packwerk::PackageTodo.any_instance
        .expects(:stale_violations?)
        .with(files_for_processing)
        .returns(false)

      refute @offense_collection.stale_violations?(files_for_processing)
    end

    test "#listed? returns true if constant is listed in file" do
      package = Package.new(name: "buyer", config: {})
      reference = build_reference(source_package: package)
      package_todo = Packwerk::PackageTodo.new(package, ".")
      package_todo
        .stubs(:listed?)
        .with(reference, violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE)
        .returns(true)
      Packwerk::PackageTodo
        .stubs(:new)
        .with(package, "./buyer/package_todo.yml")
        .returns(package_todo)

      offense = Packwerk::ReferenceOffense.new(
        reference: reference,
        violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE,
        message: "some message"
      )

      assert @offense_collection.listed?(offense)
    end

    test "#listed? returns false if constant is not listed in file " do
      offense = Packwerk::ReferenceOffense.new(
        reference: build_reference,
        violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE,
        message: "some message"
      )

      refute @offense_collection.listed?(offense)
    end

    test "adds the offense to the list of strict mode violations if decided by the checker" do
      source_package = Packwerk::Package.new(
        name: "components/source",
        config: { "enforce_dependencies" => "strict" }
      )

      known_offense = Packwerk::ReferenceOffense.new(
        reference: build_reference(source_package: source_package),
        violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE,
        message: "some message"
      )
      unknown_offense = Packwerk::ReferenceOffense.new(
        reference: build_reference(source_package: source_package),
        violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE,
        message: "some message"
      )

      Packwerk::PackageTodo.any_instance
        .expects(:listed?)
        .with(known_offense.reference, violation_type: known_offense.violation_type)
        .returns(true)
      Packwerk::PackageTodo.any_instance
        .expects(:add_entries)
        .with(known_offense.reference, known_offense.violation_type)
        .returns(true)
      Packwerk::PackageTodo.any_instance
        .expects(:listed?)
        .with(unknown_offense.reference, violation_type: unknown_offense.violation_type)
        .returns(false)

      @offense_collection.add_offense(known_offense)
      @offense_collection.add_offense(unknown_offense)

      assert_equal [known_offense, unknown_offense], @offense_collection.strict_mode_violations
    end
  end
end
