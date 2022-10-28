# typed: true
# frozen_string_literal: true

require "test_helper"
require "rails_test_helper"

module Packwerk
  class ParseRunTest < Minitest::Test
    include FactoryHelper
    include ApplicationFixtureHelper

    setup do
      setup_application_fixture
    end

    teardown do
      teardown_application_fixture
    end

    test "#detect_stale_violations returns expected Result when stale violations present" do
      use_template(:minimal)
      OffenseCollection.any_instance.stubs(:stale_violations?).returns(true)
      RunContext.any_instance.stubs(:process_file).returns([])

      parse_run = Packwerk::ParseRun.new(
        relative_file_set: Set.new(["path/of/exile.rb"]),
        configuration: Configuration.from_path
      )
      result = parse_run.detect_stale_violations
      assert_equal "There were stale violations found, please run `packwerk update-todo`", result.message
      refute result.status
    end

    test "#update-todo returns success when there are no offenses" do
      use_template(:minimal)
      RunContext.any_instance.stubs(:process_file).returns([])
      OffenseCollection.any_instance.expects(:dump_package_todo_files).once

      parse_run = Packwerk::ParseRun.new(
        relative_file_set: Set.new(["path/of/exile.rb"]),
        configuration: Configuration.from_path
      )
      result = parse_run.update_todo

      assert_equal result.message, <<~EOS
        No offenses detected
        ✅ `package_todo.yml` has been updated.
      EOS
      assert result.status
    end

    test "#update-todo returns exit code 1 when there are offenses" do
      use_template(:minimal)
      offense = Offense.new(file: "path/of/exile.rb", message: "something")
      RunContext.any_instance.stubs(:process_file).returns([offense])
      OffenseCollection.any_instance.expects(:dump_package_todo_files).once

      parse_run = Packwerk::ParseRun.new(
        relative_file_set: Set.new(["path/of/exile.rb"]),
        configuration: Configuration.from_path
      )
      result = parse_run.update_todo

      expected = <<~EOS
        path/of/exile.rb
        something

        1 offense detected

        ✅ `package_todo.yml` has been updated.
      EOS
      assert_equal expected, result.message
      refute result.status
    end

    test "#check only reports error progress for unlisted violations" do
      use_template(:minimal)
      offense = ReferenceOffense.new(
        reference: build_reference,
        message: "some message",
        violation_type: ReferenceChecking::Checkers::PrivacyChecker::VIOLATION_TYPE
      )

      PackageTodo.any_instance.stubs(:listed?).returns(true)
      out = StringIO.new
      parse_run = Packwerk::ParseRun.new(
        relative_file_set: Set.new(["some/path.rb"]),
        configuration: Configuration.new({ "parallel" => false }),
        progress_formatter: Packwerk::Formatters::ProgressFormatter.new(out)
      )
      RunContext.any_instance.stubs(:process_file).returns([offense])
      result = parse_run.check

      expected_output = <<~EOS
        📦 Packwerk is inspecting 1 file
        \\.
        📦 Finished in \\d+\\.\\d+ seconds
      EOS
      assert_match(/#{expected_output}/, out.string)

      assert result.status
      expected_message = <<~EOS
        No offenses detected
        No stale violations detected
      EOS
      assert_equal expected_message, result.message
    end

    test "#check lists stale violations when run on a single file with new violations when the containing package has violations" do
      use_template(:minimal)
      file_to_check = "components/source/some/path.rb"
      other_file = "components/source/some/other/path.rb"

      source_package_name = "components/source"
      source_package = Packwerk::Package.new(name: "components/source", config: {})
      destination_package = Packwerk::Package.new(name: "components/destination", config: {})
      write_app_file("#{source_package_name}/package_todo.yml", <<~YML.strip)
        ---
        "components/destination":
          "::SomeName":
            violations:
            - privacy
            files:
            - #{other_file}
            - #{file_to_check}
          "::SomeOtherName":
            violations:
            - privacy
            files:
            - #{other_file}
          "::SomeStaleViolation":
            violations:
            - privacy
            files:
            - #{file_to_check}
      YML

      reference1 = build_reference(
        source_package: source_package,
        destination_package: destination_package,
        path: file_to_check
      )

      reference2 = build_reference(
        source_package: source_package,
        destination_package: destination_package,
        path: file_to_check
      )

      offense1 = ReferenceOffense.new(
        reference: reference1,
        message: "some message",
        violation_type: ReferenceChecking::Checkers::PrivacyChecker::VIOLATION_TYPE
      )

      offense2 = ReferenceOffense.new(
        reference: reference2,
        message: "some message",
        violation_type: ReferenceChecking::Checkers::PrivacyChecker::VIOLATION_TYPE
      )

      out = StringIO.new
      parse_run = Packwerk::ParseRun.new(
        relative_file_set: Set.new([file_to_check]),
        configuration: Configuration.new({ "parallel" => false }),
        progress_formatter: Packwerk::Formatters::ProgressFormatter.new(out)
      )
      RunContext.any_instance.stubs(:process_file).returns([offense1, offense2])
      result = parse_run.check

      expected_output = <<~EOS
        📦 Packwerk is inspecting 1 file
        \\.
        📦 Finished in \\d+\\.\\d+ seconds
      EOS
      assert_match(/#{expected_output}/, out.string)

      expected_message = <<~EOS
        No offenses detected
        There were stale violations found, please run `packwerk update-todo`
      EOS
      assert_equal expected_message, result.message

      refute result.status
    end

    test "#check does not list stale violations when run on a single file with no violations, even if the containing package has violations" do
      use_template(:minimal)
      file_to_check = "components/source/some/path.rb"
      other_file = "components/source/some/other/path.rb"

      source_package_name = "components/source"
      write_app_file("#{source_package_name}/package_todo.yml", <<~YML.strip)
        ---
        "components/destination":
          "::SomeName":
            violations:
            - privacy
            files:
            - #{other_file}
          "::SomeOtherName":
            violations:
            - privacy
            files:
            - #{other_file}
      YML

      out = StringIO.new
      parse_run = Packwerk::ParseRun.new(
        relative_file_set: Set.new([file_to_check]),
        configuration: Configuration.new({ "parallel" => false }),
        progress_formatter: Packwerk::Formatters::ProgressFormatter.new(out)
      )
      RunContext.any_instance.stubs(:process_file).returns([])
      result = parse_run.check

      expected_output = <<~EOS
        📦 Packwerk is inspecting 1 file
        \\.
        📦 Finished in \\d+\\.\\d+ seconds
      EOS
      assert_match(/#{expected_output}/, out.string)

      expected_message = <<~EOS
        No offenses detected
        No stale violations detected
      EOS
      assert_equal expected_message, result.message

      assert result.status
    end

    test "#check does not list stale violations when run on a single file with violations, even if the containing package has violations" do
      use_template(:minimal)
      file_to_check = "components/source/some/path.rb"
      other_file = "components/source/some/other/path.rb"

      source_package_name = "components/source"
      write_app_file("#{source_package_name}/deprecated_references.yml", <<~YML.strip)
        ---
        "components/destination":
          "::SomeName":
            violations:
            - privacy
            files:
            - #{other_file}
            - #{file_to_check}
          "::SomeOtherName":
            violations:
            - privacy
            files:
            - #{other_file}
      YML

      out = StringIO.new
      parse_run = Packwerk::ParseRun.new(
        relative_file_set: Set.new([file_to_check]),
        configuration: Configuration.new({ "parallel" => false }),
        progress_formatter: Packwerk::Formatters::ProgressFormatter.new(out)
      )

      offense = ReferenceOffense.new(
        reference: build_reference(path: file_to_check),
        message: "some message",
        violation_type: Packwerk::ReferenceChecking::Checkers::PrivacyChecker::VIOLATION_TYPE
      )

      RunContext.any_instance.stubs(:process_file).returns([offense])
      result = parse_run.check

      expected_output = <<~EOS
        📦 Packwerk is inspecting 1 file
        .
        📦 Finished in \\d+\\.\\d+ seconds
      EOS

      assert_match(/#{expected_output}/, out.string)

      expected_message = <<~EOS
        No offenses detected
        No stale violations detected
      EOS
      assert_equal expected_message, result.message

      assert result.status
    end

    test "#check does not list stale violations when run on a single file with no exising violations, but one new violation" do
      use_template(:minimal)
      file_to_check = "components/source/some/path.rb"
      other_file = "components/source/some/other/path.rb"

      source_package_name = "components/source"
      write_app_file("#{source_package_name}/deprecated_references.yml", <<~YML.strip)
        ---
        "components/destination":
          "::SomeName":
            violations:
            - privacy
            files:
            - #{other_file}
          "::SomeOtherName":
            violations:
            - privacy
            files:
            - #{other_file}
      YML

      out = StringIO.new
      parse_run = Packwerk::ParseRun.new(
        relative_file_set: Set.new([file_to_check]),
        configuration: Configuration.new({ "parallel" => false }),
        progress_formatter: Packwerk::Formatters::ProgressFormatter.new(out)
      )

      offense = ReferenceOffense.new(
        reference: build_reference(path: file_to_check),
        message: "some message",
        violation_type: Packwerk::ReferenceChecking::Checkers::PrivacyChecker::VIOLATION_TYPE
      )

      RunContext.any_instance.stubs(:process_file).returns([offense])
      result = parse_run.check

      expected_output = <<~EOS
        📦 Packwerk is inspecting 1 file
        .
        📦 Finished in \\d+\\.\\d+ seconds
      EOS

      assert_match(/#{expected_output}/, out.string)

      expected_message = <<~EOS
        components/source/some/path.rb
        some message

        1 offense detected

        No stale violations detected
      EOS

      assert_equal expected_message, result.message

      refute result.status
    end

    test "#check result has failure status when stale violations exist" do
      use_template(:minimal)
      offense = ReferenceOffense.new(
        reference: build_reference,
        message: "some message",
        violation_type: ReferenceChecking::Checkers::PrivacyChecker::VIOLATION_TYPE
      )

      PackageTodo.any_instance.stubs(:listed?).returns(true)
      OffenseCollection.any_instance.stubs(:stale_violations?).returns(true)
      out = StringIO.new
      parse_run = Packwerk::ParseRun.new(
        relative_file_set: Set.new(["some/path.rb"]),
        configuration: Configuration.new({ "parallel" => false }),
        progress_formatter: Packwerk::Formatters::ProgressFormatter.new(out)
      )
      RunContext.any_instance.stubs(:process_file).returns([offense])
      result = parse_run.check

      expected_output = <<~EOS
        📦 Packwerk is inspecting 1 file
        \\.
        📦 Finished in \\d+\\.\\d+ seconds
      EOS
      assert_match(/#{expected_output}/, out.string)

      expected_message = <<~EOS
        No offenses detected
        There were stale violations found, please run `packwerk update-todo`
      EOS

      refute result.status
      assert_equal expected_message, result.message
    end

    test "runs in parallel" do
      use_template(:minimal)
      offense = ReferenceOffense.new(
        reference: build_reference,
        message: "some message",
        violation_type: ReferenceChecking::Checkers::PrivacyChecker::VIOLATION_TYPE
      )

      offense2 = ReferenceOffense.new(
        reference: build_reference(path: "some/other_path.rb"),
        message: "some message",
        violation_type: ReferenceChecking::Checkers::PrivacyChecker::VIOLATION_TYPE
      )
      parse_run = Packwerk::ParseRun.new(
        relative_file_set: Set.new(["some/path.rb", "some/other_path.rb"]),
        configuration: Configuration.new
      )
      RunContext.any_instance.stubs(:process_file).returns([offense]).returns([offense2])

      result = parse_run.check
      refute result.status
      assert_match(/2 offenses detected/, result.message)
    end
  end
end
