# typed: false
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class DependencyCheckerTest < Minitest::Test
    include ApplicationFixtureHelper
    include FactoryHelper

    class CheckingDeprecatedReferencesStub
      include ReferenceLister

      def listed?(_references, violation_type:)
        violation_type == ViolationType::Dependency
      end
    end

    setup do
      setup_application_fixture
      use_template(:skeleton)
      @reference_lister = CheckingDeprecatedReferences.new(app_dir)
    end

    teardown do
      teardown_application_fixture
    end

    test "recognizes simple cross package reference" do
      source_package = Package.new(name: "components/sales", config: { "enforce_dependencies" => true })
      checker = dependency_checker
      reference = build_reference(source_package: source_package)

      assert checker.invalid_reference?(reference, @reference_lister)
    end

    test "ignores violations when enforcement is disabled in that package" do
      source_package = Package.new(name: "components/sales", config: { "enforce_dependencies" => false })
      checker = dependency_checker
      reference = build_reference(source_package: source_package)

      refute checker.invalid_reference?(reference, @reference_lister)
    end

    test "allows reference to constants of a declared dependency" do
      source_package = Package.new(
        name: "components/sales",
        config: { "enforce_dependencies" => true, "dependencies" => ["components/destination"] }
      )
      checker = dependency_checker
      reference = build_reference(source_package: source_package)

      refute checker.invalid_reference?(reference, @reference_lister)
    end

    test "allows reference if it is in the deprecated references file" do
      source_package = Package.new(name: "components/sales", config: { "enforce_dependencies" => true })
      @reference_lister = CheckingDeprecatedReferencesStub.new
      reference = build_reference(source_package: source_package)

      # create checker after reference is added to deprecated references list, as checker reads list on instantiation
      checker = dependency_checker
      refute checker.invalid_reference?(reference, @reference_lister)
    end

    private

    def dependency_checker
      DependencyChecker.new
    end
  end
end
