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

    private

    def dependency_checker
      ReferenceChecking::Checkers::DependencyChecker.new
    end
  end
end
