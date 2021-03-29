# typed: false
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class DeprecatedReferencesTest < Minitest::Test
    test "#listed? returns true if constant is violated" do
      violated_reference =
        Reference.new(
          nil,
          "orders/app/jobs/orders/sweepers/purge_old_document_rows_task.rb",
          ConstantDiscovery::ConstantContext.new(
            "::Buyers::Document",
            "autoload/buyers/document.rb",
            destination_package,
            false
          )
        )

      offense = ReferenceOffense.new(reference: violated_reference, violation_type: ViolationType::Dependency)

      deprecated_references = DeprecatedReferences.new(destination_package, "test/fixtures/deprecated_references.yml")

      assert deprecated_references.listed?(offense)
    end

    test "#stale_violations? returns true if deprecated references exist but no violations can be found in code" do
      deprecated_references = DeprecatedReferences.new(destination_package, "test/fixtures/deprecated_references.yml")
      assert deprecated_references.stale_violations?
    end

    test "#stale_violations? returns false if deprecated references does not exist but violations are found in code" do
      deprecated_references = DeprecatedReferences.new(destination_package, "nonexistant_file_path")
      reference =
        Reference.new(
          nil,
          "some/path.rb",
          ConstantDiscovery::ConstantContext.new(
            "::Buyers::Wallet",
            "autoload/buyers/wallet.rb",
            destination_package,
            false
          )
        )
      offense = ReferenceOffense.new(reference: reference, violation_type: ViolationType::Dependency)
      deprecated_references.add_entries(offense)
      refute deprecated_references.stale_violations?
    end

    test "#stale_violations? returns false if deprecated references violation match violations found in code" do
      package = Package.new(name: "buyers", config: { "enforce_dependencies" => true })

      first_violated_reference =
        Reference.new(
          nil,
          "orders/app/jobs/orders/sweepers/purge_old_document_rows_task.rb",
          ConstantDiscovery::ConstantContext.new(
            "::Buyers::Document",
            "autoload/buyers/document.rb",
            package,
            false
          )
        )
      first_offense = ReferenceOffense.new(reference: first_violated_reference, violation_type: ViolationType::Dependency)

      second_violated_reference =
        Reference.new(
          nil,
          "orders/app/models/orders/services/adjustment_engine.rb",
          ConstantDiscovery::ConstantContext.new(
            "::Buyers::Document",
            "autoload/buyers/document.rb",
            package,
            false
          )
        )
      second_offense = ReferenceOffense.new(reference: second_violated_reference, violation_type: ViolationType::Dependency)

      deprecated_references = DeprecatedReferences.new(package, "test/fixtures/deprecated_references.yml")
      deprecated_references.add_entries(first_offense)
      deprecated_references.add_entries(second_offense)
      refute deprecated_references.stale_violations?
    end

    test "#stale_violations? returns true if dependency deprecated references violation turns into privacy deprecated references violation" do
      package = Package.new(name: "buyers", config: { "enforce_dependencies" => true })

      first_violated_reference =
        Reference.new(
          nil,
          "orders/app/jobs/orders/sweepers/purge_old_document_rows_task.rb",
          ConstantDiscovery::ConstantContext.new(
            "::Buyers::Document",
            "autoload/buyers/document.rb",
            package,
            false
          )
        )
      first_offense = ReferenceOffense.new(reference: first_violated_reference, violation_type: ViolationType::Privacy)
      second_violated_reference =
        Reference.new(
          nil,
          "orders/app/models/orders/services/adjustment_engine.rb",
          ConstantDiscovery::ConstantContext.new(
            "::Buyers::Document",
            "autoload/buyers/document.rb",
            package,
            false
          )
        )
      second_offense = ReferenceOffense.new(reference: second_violated_reference, violation_type: ViolationType::Privacy)

      deprecated_references = DeprecatedReferences.new(package, "test/fixtures/deprecated_references.yml")
      deprecated_references.add_entries(first_offense)
      deprecated_references.add_entries(second_offense)
      assert deprecated_references.stale_violations?
    end

    test "#stale_violations? returns true if violations in deprecated_references.yml exist but are not found when checking for violations" do
      package = Package.new(name: "buyers", config: { "enforce_dependencies" => true })

      violated_reference =
        Reference.new(
          nil,
          "orders/app/jobs/orders/sweepers/purge_old_document_rows_task.rb",
          ConstantDiscovery::ConstantContext.new(
            "::Buyers::Document",
            "autoload/buyers/document.rb",
            package,
            false
          )
        )
      deprecated_references = DeprecatedReferences.new(package, "test/fixtures/deprecated_references.yml")
      offense = ReferenceOffense.new(reference: violated_reference, violation_type: ViolationType::Dependency)
      deprecated_references.add_entries(offense)
      assert deprecated_references.stale_violations?
    end

    test "#listed? returns false if constant is not violated" do
      reference =
        Reference.new(
          nil,
          "some/path.rb",
          ConstantDiscovery::ConstantContext.new(
            "::Buyers::Wallet",
            "autoload/buyers/wallet.rb",
            destination_package,
            false
          )
        )

      offense = ReferenceOffense.new(reference: reference, violation_type: ViolationType::Privacy)
      deprecated_references = DeprecatedReferences.new(destination_package, "test/fixtures/deprecated_references.yml")

      refute deprecated_references.listed?(offense)
    end

    test "#listed? returns false for a constant with the same violation in deprecated references but different file" do
      violated_reference =
        Reference.new(
          nil,
          "some/path.rb",
          ConstantDiscovery::ConstantContext.new(
            "::Buyers::Document",
            "autoload/buyers/document.rb",
            destination_package,
            false
          )
        )

      offense = ReferenceOffense.new(reference: violated_reference, violation_type: ViolationType::Dependency)

      deprecated_references = DeprecatedReferences.new(destination_package, "test/fixtures/deprecated_references.yml")

      refute deprecated_references.listed?(offense)
    end

    test "#add_entries and #dump adds constant violation to file in the appropriate format" do
      expected_output = {
        "buyers" => {
          "::Checkout::Wallet" => { "violations" => ["privacy"], "files" => ["some/violated/path.rb"] },
        },
      }

      Tempfile.create("test_file.yml") do |file|
        deprecated_references = DeprecatedReferences.new(destination_package, file.path)
        package = destination_package

        reference =
          Reference.new(
            nil,
            "some/violated/path.rb",
            ConstantDiscovery::ConstantContext.new(
              "::Checkout::Wallet",
              "checkout/wallet.rb",
              package,
              false
            )
          )

        offense = ReferenceOffense.new(reference: reference, violation_type: ViolationType::Privacy)
        deprecated_references.add_entries(offense)
        deprecated_references.dump

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
        offenses = []

        second_package = Package.new(name: "another_package", config: {})
        second_package_first_reference = Reference.new(
          nil,
          "some/violated/path.rb",
          ConstantDiscovery::ConstantContext.new(
            "::Checkout::Wallet",
            "checkout/wallet.rb",
            second_package,
            false
          )
        )
        offenses << ReferenceOffense.new(reference: second_package_first_reference, violation_type: ViolationType::Privacy)
        offenses << ReferenceOffense.new(reference: second_package_first_reference, violation_type: ViolationType::Dependency)

        second_package_second_reference = Reference.new(
          nil,
          "a/b/c.rb",
          ConstantDiscovery::ConstantContext.new(
            "::Abc::Constant",
            "abc/test/ordering/constant.rb",
            second_package,
            false
          )
        )
        offenses << ReferenceOffense.new(reference: second_package_second_reference, violation_type: ViolationType::Dependency)
        offenses << ReferenceOffense.new(reference: second_package_second_reference, violation_type: ViolationType::Dependency)

        second_package_third_reference = Reference.new(
          nil,
          "this/should/come/last.rb",
          ConstantDiscovery::ConstantContext.new(
            "::Abc::Constant",
            "abc/test/ordering/constant.rb",
            second_package,
            false
          )
        )
        offenses << ReferenceOffense.new(reference: second_package_third_reference, violation_type: ViolationType::Dependency)

        first_package = Package.new(name: "a_package", config: {})
        first_package_reference = Reference.new(
          nil,
          "some/violated/path.rb",
          ConstantDiscovery::ConstantContext.new(
            "::Checkout::Wallet",
            "checkout/wallet/cash_money.rb",
            first_package,
            false
          )
        )
        offenses << ReferenceOffense.new(reference: first_package_reference, violation_type: ViolationType::Privacy)

        offenses.each { |offense| deprecated_references.add_entries(offense) }

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
