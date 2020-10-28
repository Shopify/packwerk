# typed: false
# frozen_string_literal: true

require "test_helper"
require "rails_test_helper"
require "fileutils"

module Packwerk
  module Integration
    class CustomExecutableTest < Minitest::Test
      setup do
        @out = StringIO.new
        @previous_cwd = Dir.pwd
        Dir.chdir(skeleton_root)
      end

      teardown do
        Dir.chdir(@previous_cwd)
      end

      test "'packwerk check' with no violations succeeds" do
        assert_successful_run("check")

        assert_match(/No offenses detected/, captured_output)
      end

      test "'packwerk check' with violations fails and displays violations" do
        Tempfile.create(["timeline_comment", ".rb"], timeline_path("app", "models")) do |file|
          file.write("class TimelineComment; belongs_to :order, class_name: '::Order'; end")
          file.flush

          refute_successful_run("check")
        end

        assert_match(/Privacy violation: '::Order'/, captured_output)
        assert_match(/1 offense detected/, captured_output)
      end

      test "'packwerk update-deprecations' with no violations succeeds and updates no files" do
        deprecated_reference_content = read_deprecated_references

        assert_successful_run("update-deprecations")

        deprecated_reference_content_after_update = read_deprecated_references

        assert_equal(deprecated_reference_content, deprecated_reference_content_after_update,
          "expected no updates to any deprecated references file")
        assert_match(/`deprecated_references.yml` has been updated./, captured_output)
      end

      test "'packwerk update-deprecations' with violations succeeds and updates relevant deprecated_references" do
        deprecated_reference_content = read_deprecated_references
        timeline_deprecated_reference_path = timeline_path("deprecated_references.yml")

        Tempfile.create(["timeline_comment", ".rb"], timeline_path("app", "models")) do |file|
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

          assert_equal(deprecated_reference_content, deprecated_reference_content_after_update,
            "expected no updates to any deprecated references files besides timeline/deprecated_references.yml")

          assert_match(/`deprecated_references.yml` has been updated./, captured_output)
        ensure
          File.delete(timeline_deprecated_reference_path) if File.exist?(timeline_deprecated_reference_path)
        end
      end

      test "'packwerk update-deprecations' with violations succeeds and updates relevant deprecated_references for fixture" do
        deprecated_reference_content = read_deprecated_references
        timeline_deprecated_reference_path = timeline_path("deprecated_references.yml")

        FileUtils.mkdir_p(timeline_path("test", "models"))
        Tempfile.create(["timeline_comment_test", ".rb"], timeline_path("test", "models")) do |file|
          file.write("class TimelineCommentTest; def test_order_fixture; orders(:snowdevil); end end")
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

          assert_equal(deprecated_reference_content, deprecated_reference_content_after_update,
            "expected no updates to any deprecated references files besides timeline/deprecated_references.yml")

          assert_match(/`deprecated_references.yml` has been updated./, captured_output)
        ensure
          File.delete(timeline_deprecated_reference_path) if File.exist?(timeline_deprecated_reference_path)
        end
      end

      test "'update' gives deprecation warning" do
        _out, err = capture_io { assert_successful_run("update") }
        assert_match(/`packwerk update` is deprecated/, err)
      end

      private

      def assert_successful_run(command)
        Packwerk::Cli.new(out: @out).run([command])
      rescue SystemExit => e
        assert_equal(0, e.status)
      end

      def refute_successful_run(command)
        Packwerk::Cli.new(out: @out).run([command])
      rescue SystemExit => e
        refute_equal(0, e.status)
      end

      def skeleton_root
        File.join("test", "fixtures", "skeleton")
      end

      def timeline_path(*path)
        File.join("components", "timeline", *path)
      end

      def captured_output
        @out.string
      end

      def read_deprecated_references
        deprecated_references_glob = File.join("**", "deprecated_references.yml")
        deprecated_references_files = Dir.glob(deprecated_references_glob)
        Hash[deprecated_references_files.collect { |file| [file, File.read(file)] }]
      end
    end
  end
end
