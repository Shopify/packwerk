# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class DependencyCheckerTest < Minitest::Test
    include FactoryHelper

    test "recognizes simple cross package reference" do
      source_package = Package.new(name: "components/sales", config: { "enforce_dependencies" => true })
      checker = dependency_checker
      reference = build_reference(source_package: source_package)

      assert checker.invalid_reference?(reference)
    end

    test "ignores violations when enforcement is disabled in that package" do
      source_package = Package.new(name: "components/sales", config: { "enforce_dependencies" => false })
      checker = dependency_checker
      reference = build_reference(source_package: source_package)

      refute checker.invalid_reference?(reference)
    end

    test "allows reference to constants of a declared dependency" do
      source_package = Package.new(
        name: "components/sales",
        config: { "enforce_dependencies" => true, "dependencies" => ["components/destination"] }
      )
      checker = dependency_checker
      reference = build_reference(source_package: source_package)

      refute checker.invalid_reference?(reference)
    end

    test "does not report any violation as strict in non strict mode" do
      source_package = Package.new(name: "components/sales", config: { "enforce_dependencies" => true })
      checker = dependency_checker

      offense = Packwerk::ReferenceOffense.new(
        reference: build_reference(source_package: source_package),
        violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE,
        message: "some message"
      )

      assert checker.invalid_reference?(offense.reference)
      refute checker.strict_mode_violation?(offense, already_listed: true)
      refute checker.strict_mode_violation?(offense, already_listed: false)
    end

    test "reports any violation as strict in strict mode" do
      source_package = Package.new(name: "components/sales", config: { "enforce_dependencies" => "strict" })
      checker = dependency_checker

      offense = Packwerk::ReferenceOffense.new(
        reference: build_reference(source_package: source_package),
        violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE,
        message: "some message"
      )

      assert checker.invalid_reference?(offense.reference)
      assert checker.strict_mode_violation?(offense, already_listed: true)
      assert checker.strict_mode_violation?(offense, already_listed: false)
    end

    test "only reports unlisted violations as strict in strict_for_new mode" do
      source_package = Package.new(name: "components/sales", config: { "enforce_dependencies" => "strict_for_new" })
      checker = dependency_checker

      offense = Packwerk::ReferenceOffense.new(
        reference: build_reference(source_package: source_package),
        violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE,
        message: "some message"
      )

      assert checker.invalid_reference?(offense.reference)
      refute checker.strict_mode_violation?(offense, already_listed: true)
      assert checker.strict_mode_violation?(offense, already_listed: false)
    end

    private

    def dependency_checker
      ReferenceChecking::Checkers::DependencyChecker.new
    end
  end
end
