# typed: false
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class DependencyCheckerTest < Minitest::Test
    include ApplicationFixtureHelper

    setup do
      setup_application_fixture
      use_template(:skeleton)
      @destination_package = Package.new(name: "destination_package", config: {})
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

      assert checker.invalid_reference?(reference)
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

      refute checker.invalid_reference?(reference)
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

      refute checker.invalid_reference?(reference)
    end

    private

    def dependency_checker
      DependencyChecker.new
    end
  end
end
