# frozen_string_literal: true
require "test_helper"
require "rails_test_helper"

module Packwerk
  class ParseRunTest < Minitest::Test
    include FactoryHelper

    test "#detect_stale_violations returns expected Result when stale violations present" do
      OffenseCollection.any_instance.stubs(:stale_violations?).returns(true)
      RunContext.any_instance.stubs(:process_file).returns([])

      parse_run = Packwerk::ParseRun.new(files: ["path/of/exile.rb"], configuration: Configuration.from_path)
      result = parse_run.detect_stale_violations
      assert_equal "There were stale violations found, please run `packwerk update-deprecations`", result.message
      refute result.status
    end

    test "#update_deprecations returns success when there are no offenses" do
      RunContext.any_instance.stubs(:process_file).returns([])
      OffenseCollection.any_instance.expects(:dump_deprecated_references_files).once

      parse_run = Packwerk::ParseRun.new(files: ["path/of/exile.rb"], configuration: Configuration.from_path)
      result = parse_run.update_deprecations

      assert_equal result.message, <<~EOS
        No offenses detected 🎉
        ✅ `deprecated_references.yml` has been updated.
      EOS
      assert result.status
    end

    test "#update_deprecations returns exit code 1 when there are offenses" do
      offense = Offense.new(file: "path/of/exile.rb", message: "something")
      RunContext.any_instance.stubs(:process_file).returns([offense])
      OffenseCollection.any_instance.expects(:dump_deprecated_references_files).once

      parse_run = Packwerk::ParseRun.new(files: ["path/of/exile.rb"], configuration: Configuration.from_path)
      result = parse_run.update_deprecations

      expected = <<~EOS
        path/of/exile.rb
        something

        1 offense detected

        ✅ `deprecated_references.yml` has been updated.
      EOS
      assert_equal expected, result.message
      refute result.status
    end

    test "#check only reports error progress for unlisted violations" do
      offense = ReferenceOffense.new(reference: build_reference, violation_type: ViolationType::Privacy)
      DeprecatedReferences.any_instance.stubs(:listed?).returns(true)
      out = StringIO.new
      parse_run = Packwerk::ParseRun.new(
        files: ["some/path.rb"],
        configuration: Configuration.from_path,
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
      assert_equal "No offenses detected 🎉", result.message
    end
  end
end
