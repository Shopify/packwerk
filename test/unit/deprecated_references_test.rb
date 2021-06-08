# typed: false
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class DeprecatedReferencesTest < Minitest::Test
    include FactoryHelper

    test "#listed? returns true if constant is violated" do
      violated_reference = build_reference(
        destination_package: destination_package,
        path: "orders/app/jobs/orders/sweepers/purge_old_document_rows_task.rb",
        constant_name: "::Buyers::Document"
      )
      deprecated_references = DeprecatedReferences.new(destination_package, "test/fixtures/deprecated_references.yml")

      assert deprecated_references.listed?(
        violated_reference,
        violation_type: ViolationType::Dependency
      )
    end

    test "#stale_violations? returns true if deprecated references exist but no violations can be found in code" do
      deprecated_references = DeprecatedReferences.new(destination_package, "test/fixtures/deprecated_references.yml")
      assert deprecated_references.stale_violations?
    end

    test "#stale_violations? returns false if deprecated references does not exist but violations are found in code" do
      deprecated_references = DeprecatedReferences.new(destination_package, "nonexistant_file_path")
      deprecated_references.add_entries(build_reference, ViolationType::Dependency)
      refute deprecated_references.stale_violations?
    end

    test "#stale_violations? returns false if deprecated references violation match violations found in code" do
      package = Package.new(name: "buyers", config: { "enforce_dependencies" => true })

      first_violated_reference = build_reference(
        destination_package: package,
        path: "orders/app/jobs/orders/sweepers/purge_old_document_rows_task.rb",
        constant_name: "::Buyers::Document"
      )
      second_violated_reference = build_reference(
        destination_package: package,
        path: "orders/app/models/orders/services/adjustment_engine.rb",
        constant_name: "::Buyers::Document"
      )

      deprecated_references = DeprecatedReferences.new(package, "test/fixtures/deprecated_references.yml")
      deprecated_references.add_entries(first_violated_reference, Packwerk::ViolationType::Dependency)
      deprecated_references.add_entries(second_violated_reference, Packwerk::ViolationType::Dependency)
      refute deprecated_references.stale_violations?
    end

    test "#stale_violations? returns true if dependency deprecated references violation turns into privacy deprecated references violation" do
      package = Package.new(name: "buyers", config: { "enforce_dependencies" => true })

      first_violated_reference = build_reference(
        destination_package: package,
        path: "orders/app/jobs/orders/sweepers/purge_old_document_rows_task.rb",
        constant_name: "::Buyers::Document"
      )
      second_violated_reference = build_reference(
        destination_package: package,
        path: "orders/app/models/orders/services/adjustment_engine.rb",
        constant_name: "::Buyers::Document"
      )

      deprecated_references = DeprecatedReferences.new(package, "test/fixtures/deprecated_references.yml")
      deprecated_references.add_entries(first_violated_reference, Packwerk::ViolationType::Privacy)
      deprecated_references.add_entries(second_violated_reference, Packwerk::ViolationType::Privacy)
      assert deprecated_references.stale_violations?
    end

    test "#stale_violations? returns true if violations in deprecated_references.yml exist but are not found when checking for violations" do
      package = Package.new(name: "buyers", config: { "enforce_dependencies" => true })

      violated_reference = build_reference(
        destination_package: package,
        path: "orders/app/jobs/orders/sweepers/purge_old_document_rows_task.rb",
        constant_name: "::Buyers::Document"
      )
      deprecated_references = DeprecatedReferences.new(package, "test/fixtures/deprecated_references.yml")
      deprecated_references.add_entries(violated_reference, ViolationType::Dependency)
      assert deprecated_references.stale_violations?
    end

    test "#listed? returns false if constant is not violated" do
      reference = build_reference(destination_package: destination_package)
      deprecated_references = DeprecatedReferences.new(destination_package, "test/fixtures/deprecated_references.yml")

      refute deprecated_references.listed?(
        reference,
        violation_type: ViolationType::Privacy
      )
    end

    test "#listed? returns false for a constant with the same violation in deprecated references but different file" do
      violated_reference = build_reference(
        destination_package: destination_package,
        constant_name: "::Buyers::Document"
      )
      deprecated_references = DeprecatedReferences.new(destination_package, "test/fixtures/deprecated_references.yml")

      refute deprecated_references.listed?(
        violated_reference,
        violation_type: ViolationType::Dependency
      )
    end

    test "#add_entries and #dump adds constant violation to file in the appropriate format" do
      Tempfile.create("test_file.yml") do |file|
        reference = build_reference
        deprecated_references = DeprecatedReferences.new(reference.constant.package, file.path)

        deprecated_references.add_entries(reference, Packwerk::ViolationType::Privacy)
        deprecated_references.dump

        expected_output = {
          reference.constant.package.name => {
            reference.constant.name => { "violations" => ["privacy"], "files" => [reference.relative_path] },
          },
        }

        assert_equal expected_output, YAML.load_file(file)
      end
    end

    test "#dump dumps a deprecated references file with sorted and unique package, constant and file violations" do
      expected_output = {
        "a_package" => {
          "::Checkout::Wallet" => { "violations" => ["privacy"], "files" => ["some/violated/path.rb"] },
        },
        "another_package" => {
          "::Abc::Constant" => { "violations" => ["dependency"], "files" => ["a/b/c.rb", "this/should/come/last.rb"] },
          "::Checkout::Wallet" => { "violations" => ["dependency", "privacy"], "files" => ["some/violated/path.rb"] },
        },
      }

      Tempfile.create("test_file.yml") do |file|
        deprecated_references = DeprecatedReferences.new(destination_package, file.path)

        first_package = Package.new(name: "a_package", config: {})
        second_package = Package.new(name: "another_package", config: {})
        first_package_reference = build_reference(
          destination_package: first_package,
          constant_name: "::Checkout::Wallet",
          path: "some/violated/path.rb"
        )

        second_package_first_reference = build_reference(
          destination_package: second_package,
          constant_name: "::Checkout::Wallet",
          path: "some/violated/path.rb"
        )

        second_package_second_reference = build_reference(
          destination_package: second_package,
          constant_name: "::Abc::Constant",
          path: "a/b/c.rb"
        )

        second_package_third_reference = build_reference(
          destination_package: second_package,
          constant_name: "::Abc::Constant",
          path: "this/should/come/last.rb"
        )

        deprecated_references.add_entries(second_package_first_reference, Packwerk::ViolationType::Privacy)
        deprecated_references.add_entries(second_package_first_reference, Packwerk::ViolationType::Dependency)
        deprecated_references.add_entries(second_package_second_reference, Packwerk::ViolationType::Dependency)
        deprecated_references.add_entries(second_package_second_reference, Packwerk::ViolationType::Dependency)
        deprecated_references.add_entries(second_package_third_reference, Packwerk::ViolationType::Dependency)
        deprecated_references.add_entries(first_package_reference, Packwerk::ViolationType::Privacy)

        deprecated_references.dump

        assert_equal expected_output.to_a, YAML.load_file(file).to_a
      end
    end

    test "#dump deletes the deprecated references if there are no entries" do
      file = Tempfile.new("empty_deprecated_references.yml")
      deprecated_references = DeprecatedReferences.new(destination_package, file.path)
      deprecated_references.dump

      refute File.exist?(file.path)
    end

    private

    def destination_package
      @destination_package ||= Package.new(name: "buyers", config: {})
    end
  end
end
