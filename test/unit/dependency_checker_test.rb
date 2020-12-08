# typed: false
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class DependencyCheckerTest < Minitest::Test
    include ApplicationFixtureHelper

    class CheckingDeprecatedReferencesStub
      include ReferenceLister

      def listed?(_references, violation_type:)
        violation_type == ViolationType::Dependency
      end
    end

    setup do
      setup_application_fixture
      use_template(:skeleton)
      @destination_package = Package.new(name: "destination_package", config: {})
      @reference_lister = CheckingDeprecatedReferences.new(app_dir)
    end

    teardown do
      teardown_application_fixture
    end

    test "recognizes simple cross package reference" do
      source_package = Package.new(name: "components/sales", config: { "enforce_dependencies" => true })
      checker = dependency_checker

      reference =
        Reference.new(
          source_package,
          "some/path.rb",
          ConstantDiscovery::ConstantContext.new(
            "::SomeName",
            "some/location.rb",
            @destination_package,
            false
          )
        )

      assert checker.invalid_reference?(reference, @reference_lister)
    end

    test "ignores violations when enforcement is disabled in that package" do
      source_package = Package.new(name: "components/sales", config: { "enforce_dependencies" => false })
      checker = dependency_checker

      reference =
        Reference.new(
          source_package,
          "some/path.rb",
          ConstantDiscovery::ConstantContext.new(
            "::SomeName",
            "some/location.rb",
            @destination_package,
            false
          )
        )

      refute checker.invalid_reference?(reference, @reference_lister)
    end

    test "allows reference to constants of a declared dependency" do
      source_package = Package.new(
        name: "components/sales",
        config: { "enforce_dependencies" => true, "dependencies" => ["destination_package"] }
      )
      checker = dependency_checker

      reference =
        Reference.new(
          source_package,
          "some/path.rb",
          ConstantDiscovery::ConstantContext.new(
            "::SomeName",
            "some/location.rb",
            @destination_package,
            false
          )
        )

      refute checker.invalid_reference?(reference, @reference_lister)
    end

    test "allows reference if it is in the deprecated references file" do
      source_package = Package.new(name: "components/sales", config: { "enforce_dependencies" => true })
      @reference_lister = CheckingDeprecatedReferencesStub.new

      reference =
        Reference.new(
          source_package,
          "some/path.rb",
          ConstantDiscovery::ConstantContext.new(
            "::SomeName",
            "some/location.rb",
            @destination_package,
            false
          )
        )

      # create checker after reference is added to deprecated references list, as checker reads list on instantiation
      checker = dependency_checker
      refute checker.invalid_reference?(reference, @reference_lister)
    end

    test "renders a sensible error message" do
      source_package = Package.new(
        name: "components/sales",
        config: { "enforce_dependencies" => true, "dependencies" => ["destination_package"] }
      )
      checker = dependency_checker

      reference =
        Reference.new(
          source_package,
          "some/path.rb",
          ConstantDiscovery::ConstantContext.new(
            "::SomeName",
            "some/location.rb",
            @destination_package,
            false
          )
        )

      expected = <<~EXPECTED
        Dependency violation: ::SomeName belongs to 'destination_package', but 'components/sales' does not specify a dependency on 'destination_package'.
        Are we missing an abstraction?
        Is the code making the reference, and the referenced constant, in the right packages?
      EXPECTED

      assert_equal(expected, checker.message_for(reference))
    end

    private

    def dependency_checker
      DependencyChecker.new
    end
  end
end
