# typed: true
# frozen_string_literal: true

require "test_helper"
require "support/rails_test_helper"

module Packwerk
  module Commands
    class CheckCommandTest < Minitest::Test
      include FactoryHelper
      include ApplicationFixtureHelper

      setup do
        setup_application_fixture
      end

      teardown do
        teardown_application_fixture
      end

      test "#run only reports error progress for unlisted violations" do
        use_template(:minimal)
        offense = ReferenceOffense.new(
          reference: build_reference,
          message: "some message",
          violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE
        )

        PackageTodo.any_instance.stubs(:listed?).returns(true)
        RunContext.any_instance.stubs(:process_file).returns([offense])
        FilesForProcessing.any_instance.stubs(:files).returns(Set.new(["some/path.rb"]))

        out = StringIO.new
        configuration = Configuration.new({ "parallel" => false })
        check_command = CheckCommand.new(
          [],
          configuration: configuration,
          out: out,
          err_out: StringIO.new,
          progress_formatter: Formatters::ProgressFormatter.new(out),
          offenses_formatter: configuration.offenses_formatter
        )

        result = check_command.run

        expected_output = <<~EOS
          📦 Packwerk is inspecting 1 file
          \\.
          📦 Finished in \\d+\\.\\d+ seconds

          No offenses detected
          No stale violations detected
        EOS
        assert_match(/#{expected_output}/, out.string)

        assert result
      end

      test "#run lists stale violations when run on a single file with new violations when the containing package has violations" do
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
              - dependency
              files:
              - #{other_file}
              - #{file_to_check}
            "::SomeOtherName":
              violations:
              - dependency
              files:
              - #{other_file}
            "::SomeStaleViolation":
              violations:
              - dependency
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
          violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE
        )

        offense2 = ReferenceOffense.new(
          reference: reference2,
          message: "some message",
          violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE
        )

        RunContext.any_instance.stubs(:process_file).returns([offense1, offense2])
        FilesForProcessing.any_instance.stubs(:files).returns(Set.new([file_to_check]))

        out = StringIO.new
        configuration = Configuration.new({ "parallel" => false })
        check_command = CheckCommand.new(
          [],
          configuration: configuration,
          out: out,
          err_out: StringIO.new,
          progress_formatter: Formatters::ProgressFormatter.new(out),
          offenses_formatter: configuration.offenses_formatter
        )

        result = check_command.run

        expected_output = <<~EOS
          📦 Packwerk is inspecting 1 file
          \\.
          📦 Finished in \\d+\\.\\d+ seconds

          No offenses detected
          There were stale violations found, please run `packwerk update-todo`
        EOS
        assert_match(/#{expected_output}/, out.string)

        refute result
      end

      test "#run does not list stale violations when run on a single file with no violations, even if the containing package has violations" do
        use_template(:minimal)
        file_to_check = "components/source/some/path.rb"
        other_file = "components/source/some/other/path.rb"

        source_package_name = "components/source"
        write_app_file("#{source_package_name}/package_todo.yml", <<~YML.strip)
          ---
          "components/destination":
            "::SomeName":
              violations:
              - dependency
              files:
              - #{other_file}
            "::SomeOtherName":
              violations:
              - dependency
              files:
              - #{other_file}
        YML

        RunContext.any_instance.stubs(:process_file).returns([])
        FilesForProcessing.any_instance.stubs(:files).returns(Set.new([file_to_check]))

        out = StringIO.new
        configuration = Configuration.new({ "parallel" => false })
        check_command = CheckCommand.new(
          [],
          configuration: configuration,
          out: out,
          err_out: StringIO.new,
          progress_formatter: Formatters::ProgressFormatter.new(out),
          offenses_formatter: configuration.offenses_formatter
        )

        result = check_command.run

        expected_output = <<~EOS
          📦 Packwerk is inspecting 1 file
          \\.
          📦 Finished in \\d+\\.\\d+ seconds

          No offenses detected
          No stale violations detected
        EOS
        assert_match(/#{expected_output}/, out.string)

        assert result
      end

      test "#run does not list stale violations when run on a single file with violations, even if the containing package has violations" do
        use_template(:minimal)
        file_to_check = "components/source/some/path.rb"
        other_file = "components/source/some/other/path.rb"

        source_package_name = "components/source"
        write_app_file("#{source_package_name}/package_todo.yml", <<~YML.strip)
          ---
          "components/destination":
            "::SomeName":
              violations:
              - dependency
              files:
              - #{other_file}
              - #{file_to_check}
            "::SomeOtherName":
              violations:
              - dependency
              files:
              - #{other_file}
        YML

        offense = ReferenceOffense.new(
          reference: build_reference(path: file_to_check),
          message: "some message",
          violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE
        )

        RunContext.any_instance.stubs(:process_file).returns([offense])
        FilesForProcessing.any_instance.stubs(:files).returns(Set.new([file_to_check]))

        out = StringIO.new
        configuration = Configuration.new({ "parallel" => false })
        check_command = CheckCommand.new(
          [],
          configuration: configuration,
          out: out,
          err_out: StringIO.new,
          progress_formatter: Formatters::ProgressFormatter.new(out),
          offenses_formatter: configuration.offenses_formatter
        )

        result = check_command.run

        expected_output = <<~EOS
          📦 Packwerk is inspecting 1 file
          \\.
          📦 Finished in \\d+\\.\\d+ seconds

          No offenses detected
          There were stale violations found, please run `packwerk update-todo`
        EOS
        assert_match(/#{expected_output}/, out.string)

        refute result
      end

      test "#run lists out violations of strict mode" do
        use_template(:minimal)

        source_package = Packwerk::Package.new(
          name: "components/source",
          config: { "enforce_dependencies" => "strict" },
        )
        write_app_file("#{source_package.name}/package_todo.yml", <<~YML.strip)
          ---
          "components/destination":
            "::SomeName":
              violations:
              - dependency
              files:
              - components/source/some/path.rb
        YML

        offense = ReferenceOffense.new(
          reference: build_reference(path: "components/source/some/path.rb", source_package: source_package),
          message: "some message",
          violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE
        )

        RunContext.any_instance.stubs(:process_file).returns([offense])
        FilesForProcessing.any_instance.stubs(:files).returns(Set.new(["components/source/some/path.rb"]))

        out = StringIO.new
        configuration = Configuration.new({ "parallel" => false })
        check_command = CheckCommand.new(
          [],
          configuration: configuration,
          out: out,
          err_out: StringIO.new,
          progress_formatter: Formatters::ProgressFormatter.new(out),
          offenses_formatter: configuration.offenses_formatter
        )

        result = check_command.run

        expected_output = <<~EOS
          📦 Packwerk is inspecting 1 file
          \\.
          📦 Finished in \\d+\\.\\d+ seconds

          No offenses detected
          No stale violations detected
          components/source cannot have dependency violations on components/destination because strict mode is enabled for dependency violations in the enforcing package's package.yml
        EOS
        assert_match(/#{expected_output}/, out.string)

        refute result
      end

      test "#run does not list stale violations when run on a single file with no exising violations, but one new violation" do
        use_template(:minimal)
        file_to_check = "components/source/some/path.rb"
        other_file = "components/source/some/other/path.rb"

        source_package_name = "components/source"
        write_app_file("#{source_package_name}/package_todo.yml", <<~YML.strip)
          ---
          "components/destination":
            "::SomeName":
              violations:
              - dependency
              files:
              - #{other_file}
            "::SomeOtherName":
              violations:
              - dependency
              files:
              - #{other_file}
        YML

        offense = ReferenceOffense.new(
          reference: build_reference(path: file_to_check),
          message: "some message",
          violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE
        )

        RunContext.any_instance.stubs(:process_file).returns([offense])
        FilesForProcessing.any_instance.stubs(:files).returns(Set.new([file_to_check]))

        out = StringIO.new
        configuration = Configuration.new({ "parallel" => false, "offenses_formatter" => "plain" })
        check_command = CheckCommand.new(
          [],
          configuration: configuration,
          out: out,
          err_out: StringIO.new,
          progress_formatter: Formatters::ProgressFormatter.new(out),
          offenses_formatter: configuration.offenses_formatter
        )

        result = check_command.run

        expected_output = <<~EOS
          📦 Packwerk is inspecting 1 file
          E
          📦 Finished in \\d+\\.\\d+ seconds

          components/source/some/path.rb
          some message

          1 offense detected

          There were stale violations found, please run `packwerk update-todo`
        EOS
        assert_match(/#{expected_output}/, out.string)

        refute result
      end

      test "#run result has failure status when stale violations exist" do
        use_template(:minimal)
        offense = ReferenceOffense.new(
          reference: build_reference,
          message: "some message",
          violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE
        )

        PackageTodo.any_instance.stubs(:listed?).returns(true)
        OffenseCollection.any_instance.stubs(:stale_violations?).returns(true)
        RunContext.any_instance.stubs(:process_file).returns([offense])
        FilesForProcessing.any_instance.stubs(:files).returns(Set.new(["some/path.rb"]))

        out = StringIO.new
        configuration = Configuration.new({ "parallel" => false })
        check_command = CheckCommand.new(
          [],
          configuration: configuration,
          out: out,
          err_out: StringIO.new,
          progress_formatter: Formatters::ProgressFormatter.new(out),
          offenses_formatter: configuration.offenses_formatter
        )

        result = check_command.run

        expected_output = <<~EOS
          📦 Packwerk is inspecting 1 file
          \\.
          📦 Finished in \\d+\\.\\d+ seconds

          No offenses detected
          There were stale violations found, please run `packwerk update-todo`
        EOS
        assert_match(/#{expected_output}/, out.string)

        refute result
      end

      test "#run runs in parallel" do
        use_template(:minimal)
        offense = ReferenceOffense.new(
          reference: build_reference,
          message: "some message",
          violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE
        )

        offense2 = ReferenceOffense.new(
          reference: build_reference(path: "some/other_path.rb"),
          message: "some message",
          violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE
        )

        RunContext.any_instance.stubs(:process_file).returns([offense]).returns([offense2])
        FilesForProcessing.any_instance.stubs(:files).returns(Set.new(["some/path.rb", "some/other_path.rb"]))

        out = StringIO.new
        configuration = Configuration.new
        check_command = CheckCommand.new(
          [],
          configuration: configuration,
          out: out,
          err_out: StringIO.new,
          progress_formatter: Formatters::ProgressFormatter.new(StringIO.new),
          offenses_formatter: configuration.offenses_formatter
        )

        result = check_command.run
        refute result
        assert_match(/2 offenses detected/, out.string)
      end
    end
  end
end
