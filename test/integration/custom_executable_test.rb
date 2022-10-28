# typed: true
# frozen_string_literal: true

require "test_helper"
require "rails_test_helper"

module Packwerk
  module Integration
    class CustomExecutableTest < Minitest::Test
      include ApplicationFixtureHelper

      TIMELINE_PATH = Pathname.new("components/timeline")

      setup do
        reset_output
        setup_application_fixture
        use_template(:skeleton)
      end

      teardown do
        teardown_application_fixture
      end

      test "'packwerk check' with no violations succeeds in all variants" do
        assert_successful_run("check")
        assert_match(/No offenses detected/, captured_output)

        reset_output
        assert_successful_run(["check", "components/timeline"])
        assert_match(/No offenses detected/, captured_output)

        reset_output
        assert_successful_run(["check", "--packages=components/timeline"])
        assert_match(/No offenses detected/, captured_output)
      end

      test "'packwerk check' with violations only in nested packages has different outcomes per variant" do
        open_app_file(TIMELINE_PATH.join("nested", "timeline_comment.rb")) do |file|
          file.write("class TimelineComment; belongs_to :order, class_name: '::Order'; end")
          file.flush
        end

        refute_successful_run("check")
        assert_match(/Privacy violation: '::Order'/, captured_output)
        assert_match(/1 offense detected/, captured_output)

        reset_output
        refute_successful_run(["check", "components/timeline"])
        assert_match(/Privacy violation: '::Order'/, captured_output)
        assert_match(/1 offense detected/, captured_output)

        reset_output
        assert_successful_run(["check", "--packages=components/timeline"])
        assert_match(/No offenses detected/, captured_output)
      end

      test "'packwerk check' with failures in different parts of the app has different outcomes per variant" do
        open_app_file(TIMELINE_PATH.join("nested", "timeline_comment.rb")) do |file|
          file.write("class TimelineComment; belongs_to :order, class_name: '::Order'; end")
          file.flush
        end

        refute_successful_run("check")
        assert_match(/Privacy violation: '::Order'/, captured_output)
        assert_match(/1 offense detected/, captured_output)

        reset_output
        assert_successful_run(["check", "components/sales"])
        assert_match(/No offenses detected/, captured_output)

        reset_output
        assert_successful_run(["check", "--packages=components/sales"])
        assert_match(/No offenses detected/, captured_output)
      end

      test "'packwerk update-todo' with no violations succeeds and updates no files" do
        package_todo_content = read_package_todo

        assert_successful_run("update-todo")

        package_todo_content_after_update = read_package_todo
        expected_output = <<~EOS
          📦 Packwerk is inspecting 13 files
          \\.\\.\\.\\.\\.\\.\\.\\.\\.\\.\\.\\.\\.
          📦 Finished in \\d+\\.\\d+ seconds

          No offenses detected
          ✅ `package_todo.yml` has been updated.
        EOS

        assert_equal(package_todo_content, package_todo_content_after_update,
          "expected no updates to any package todo file")
        assert_match(/#{expected_output}/, captured_output)
      end

      test "'packwerk update-todo' with violations succeeds and updates relevant package_todo" do
        package_todo_content = read_package_todo
        timeline_package_todo_path = to_app_path(File.join(TIMELINE_PATH, "package_todo.yml"))

        open_app_file(TIMELINE_PATH.join("app", "models", "timeline_comment.rb")) do |file|
          file.write("class TimelineComment; belongs_to :order; end")
          file.flush

          assert_successful_run("update-todo")

          assert(File.exist?(timeline_package_todo_path),
            "expected new package_todo for timeline package to be created")

          timeline_package_todo_content = File.read(timeline_package_todo_path)
          assert_match(
            "components/sales:\n  \"::Order\":\n    violations:\n    - privacy",
            timeline_package_todo_content
          )

          package_todo_content_after_update =
            read_package_todo.reject { |k, _v| k.match?(timeline_package_todo_path) }
          expected_output = <<~EOS
            📦 Packwerk is inspecting 14 files
            \\.\\.\\.\\.\\.\\.\\.\\.\\.\\.\\.\\.\\.\\.
            📦 Finished in \\d+\\.\\d+ seconds

            No offenses detected
            ✅ `package_todo.yml` has been updated.
          EOS

          assert_equal(package_todo_content, package_todo_content_after_update,
            "expected no updates to any package todo files besides timeline/package_todo.yml")
          assert_match(/#{expected_output}/, captured_output)
        end
      end

      private

      def assert_successful_run(command)
        Packwerk::Cli.new(out: @out).run(Array(command))
      rescue SystemExit => e
        assert_equal(0, e.status)
      end

      def refute_successful_run(command)
        Packwerk::Cli.new(out: @out).run(Array(command))
      rescue SystemExit => e
        refute_equal(0, e.status)
      end

      def reset_output
        @out = StringIO.new
      end

      def captured_output
        @out.string
      end

      def read_package_todo
        package_todo_glob = File.join("**", "package_todo.yml")
        package_todo_files = Dir.glob(package_todo_glob)
        Hash[
          package_todo_files.collect do |file|
            [to_app_path(file), File.read(file)]
          end
        ]
      end
    end
  end
end
