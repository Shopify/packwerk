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

      test "'packwerk update-deprecations' with no violations succeeds and updates no files" do
        deprecated_reference_content = read_deprecated_references

        assert_successful_run("update-deprecations")

        deprecated_reference_content_after_update = read_deprecated_references
        expected_output = <<~EOS
          📦 Packwerk is inspecting 12 files
          \\.\\.\\.\\.\\.\\.\\.\\.\\.\\.\\.\\.
          📦 Finished in \\d+\\.\\d+ seconds

          No offenses detected
          ✅ `deprecated_references.yml` has been updated.
        EOS

        assert_equal(deprecated_reference_content, deprecated_reference_content_after_update,
          "expected no updates to any deprecated references file")
        assert_match(/#{expected_output}/, captured_output)
      end

      test "'packwerk update-deprecations' with violations succeeds and updates relevant deprecated_references" do
        deprecated_reference_content = read_deprecated_references
        timeline_deprecated_reference_path = to_app_path(File.join(TIMELINE_PATH, "deprecated_references.yml"))

        open_app_file(TIMELINE_PATH.join("app", "models", "timeline_comment.rb")) do |file|
          file.write("class TimelineComment; belongs_to :order; end")
          file.flush

          assert_successful_run("update-deprecations")

          assert(File.exist?(timeline_deprecated_reference_path),
            "expected new deprecated_reference for timeline package to be created")

          timeline_deprecated_reference_content = File.read(timeline_deprecated_reference_path)
          assert_match(
            "components/sales:\n  \"::Order\":\n    violations:\n    - privacy",
            timeline_deprecated_reference_content
          )

          deprecated_reference_content_after_update =
            read_deprecated_references.reject { |k, _v| k.match?(timeline_deprecated_reference_path) }
          expected_output = <<~EOS
            📦 Packwerk is inspecting 13 files
            \\.\\.\\.\\.\\.\\.\\.\\.\\.\\.\\.\\.\\.
            📦 Finished in \\d+\\.\\d+ seconds

            No offenses detected
            ✅ `deprecated_references.yml` has been updated.
          EOS

          assert_equal(deprecated_reference_content, deprecated_reference_content_after_update,
            "expected no updates to any deprecated references files besides timeline/deprecated_references.yml")
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

      def read_deprecated_references
        deprecated_references_glob = File.join("**", "deprecated_references.yml")
        deprecated_references_files = Dir.glob(deprecated_references_glob)
        Hash[
          deprecated_references_files.collect do |file|
            [to_app_path(file), File.read(file)]
          end
        ]
      end
    end
  end
end
