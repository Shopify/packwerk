# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class PackageTodoTest < Minitest::Test
    include FactoryHelper

    test "#listed? returns true if constant is violated" do
      violated_reference = build_reference(
        destination_package: destination_package,
        path: "orders/app/jobs/orders/sweepers/purge_old_document_rows_task.rb",
        constant_name: "::Buyers::Document"
      )
      package_todo = PackageTodo.new(destination_package, "test/fixtures/package_todo.yml")

      assert package_todo.listed?(
        violated_reference,
        violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE
      )
    end

    test "#listed? returns false if the list cannot be read" do
      violated_reference = build_reference(
        destination_package: destination_package,
        path: "orders/app/jobs/orders/sweepers/purge_old_document_rows_task.rb",
        constant_name: "::Buyers::Document"
      )
      package_todo = PackageTodo.new(
        destination_package,
        "test/fixtures/package_todo_with_conflicts.yml"
      )

      refute package_todo.listed?(
        violated_reference,
        violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE
      )
    end

    test "#stale_violations? returns true if package TODO exist but no violations can be found in code" do
      package_todo = PackageTodo.new(destination_package, "test/fixtures/package_todo.yml")
      assert package_todo.stale_violations?(Set.new([
        "orders/app/jobs/orders/sweepers/purge_old_document_rows_task.rb",
        "orders/app/models/orders/services/adjustment_engine.rb",
      ]))
    end

    test "#stale_violations? returns false if package TODO does not exist but violations are found in code" do
      package_todo = PackageTodo.new(destination_package, "nonexistant_file_path")
      package_todo.add_entries(build_reference, ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE)
      refute package_todo.stale_violations?(Set.new)
    end

    test "#stale_violations? returns false if package TODO violation match violations found in code" do
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

      package_todo = PackageTodo.new(package, "test/fixtures/package_todo.yml")
      package_todo.add_entries(first_violated_reference,
        Packwerk::ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE)
      package_todo.add_entries(second_violated_reference,
        Packwerk::ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE)
      refute package_todo.stale_violations?(Set.new([
        "orders/app/jobs/orders/sweepers/purge_old_document_rows_task.rb",
        "orders/app/models/orders/services/adjustment_engine.rb",
      ]))
    end

    test "#stale_violations? returns true if dependency package TODO violation turns into privacy package TODO violation" do
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

      package_todo = PackageTodo.new(package, "test/fixtures/package_todo.yml")
      package_todo.add_entries(first_violated_reference,
        Packwerk::ReferenceChecking::Checkers::PrivacyChecker::VIOLATION_TYPE)
      package_todo.add_entries(second_violated_reference,
        Packwerk::ReferenceChecking::Checkers::PrivacyChecker::VIOLATION_TYPE)
      assert package_todo.stale_violations?(Set.new([
        "orders/app/jobs/orders/sweepers/purge_old_document_rows_task.rb",
        "orders/app/models/orders/services/adjustment_engine.rb",
      ]))
    end

    test "#stale_violations? returns true if violations in package_todo.yml exist but are not found when checking for violations" do
      package = Package.new(name: "buyers", config: { "enforce_dependencies" => true })
      package_todo = PackageTodo.new(package, "test/fixtures/package_todo.yml")
      assert package_todo.stale_violations?(
        Set.new(["orders/app/jobs/orders/sweepers/purge_old_document_rows_task.rb"])
      )
    end

    test "#stale_violations? returns false if violations in package_todo.yml exist but are found when checking for violations" do
      package = Package.new(name: "buyers", config: { "enforce_dependencies" => true })

      violated_reference = build_reference(
        destination_package: package,
        path: "orders/app/jobs/orders/sweepers/purge_old_document_rows_task.rb",
        constant_name: "::Buyers::Document"
      )
      package_todo = PackageTodo.new(package, "test/fixtures/package_todo.yml")
      package_todo.add_entries(violated_reference,
        ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE)
      refute package_todo.stale_violations?(
        Set.new(["orders/app/jobs/orders/sweepers/purge_old_document_rows_task.rb"])
      )
    end

    test "#listed? returns false if constant is not violated" do
      reference = build_reference(destination_package: destination_package)
      package_todo = PackageTodo.new(destination_package, "test/fixtures/package_todo.yml")

      refute package_todo.listed?(
        reference,
        violation_type: ReferenceChecking::Checkers::PrivacyChecker::VIOLATION_TYPE
      )
    end

    test "#listed? returns false for a constant with the same violation in package TODO but different file" do
      violated_reference = build_reference(
        destination_package: destination_package,
        constant_name: "::Buyers::Document"
      )
      package_todo = PackageTodo.new(destination_package, "test/fixtures/package_todo.yml")

      refute package_todo.listed?(
        violated_reference,
        violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE
      )
    end

    test "#add_entries and #dump adds constant violation to file in the appropriate format" do
      Tempfile.create("test_file.yml") do |file|
        reference = build_reference
        package_todo = PackageTodo.new(reference.constant.package, file.path)

        package_todo.add_entries(reference,
          Packwerk::ReferenceChecking::Checkers::PrivacyChecker::VIOLATION_TYPE)
        package_todo.dump

        expected_output = {
          reference.constant.package.name => {
            reference.constant.name => { "violations" => ["privacy"], "files" => [reference.relative_path] },
          },
        }

        assert_equal expected_output, YAML.load_file(file.path)
      end
    end

    test "#dump dumps a package TODO file with sorted and unique package, constant and file violations" do
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
        package_todo = PackageTodo.new(destination_package, file.path)

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

        package_todo.add_entries(second_package_first_reference,
          Packwerk::ReferenceChecking::Checkers::PrivacyChecker::VIOLATION_TYPE)
        package_todo.add_entries(second_package_first_reference,
          Packwerk::ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE)
        package_todo.add_entries(second_package_second_reference,
          Packwerk::ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE)
        package_todo.add_entries(second_package_second_reference,
          Packwerk::ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE)
        package_todo.add_entries(second_package_third_reference,
          Packwerk::ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE)
        package_todo.add_entries(first_package_reference,
          Packwerk::ReferenceChecking::Checkers::PrivacyChecker::VIOLATION_TYPE)

        package_todo.dump

        assert_equal expected_output.to_a, YAML.load_file(file.path).to_a
      end
    end

    test "#dump deletes the package TODO if there are no entries" do
      file = Tempfile.new("empty_package_todo.yml")
      package_todo = PackageTodo.new(destination_package, T.must(file.path))
      package_todo.dump

      refute File.exist?(file.path)
    end

    private

    def destination_package
      @destination_package ||= Package.new(name: "buyers", config: {})
    end
  end
end
