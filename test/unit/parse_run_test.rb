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
      run_context = RunContext.from_configuration(Configuration.from_path)
      run_context.stubs(:process_file).returns([])

      parse_run = Packwerk::ParseRun.new(
        relative_file_set: Set.new(["path/of/exile.rb"]),
        run_context: run_context
      )
      result = parse_run.detect_stale_violations
      assert_equal "There were stale violations found, please run `packwerk update-deprecations`", result.message
      refute result.status
    end

    test "#update_deprecations returns success when there are no offenses" do
      use_template(:minimal)
      run_context = RunContext.from_configuration(Configuration.from_path)
      run_context.stubs(:process_file).returns([])
      OffenseCollection.any_instance.expects(:dump_deprecated_references_files).once

      parse_run = Packwerk::ParseRun.new(
        relative_file_set: Set.new(["path/of/exile.rb"]),
        run_context: run_context
      )
      result = parse_run.update_deprecations

      assert_equal result.message, <<~EOS
        No offenses detected
        ✅ `deprecated_references.yml` has been updated.
      EOS
      assert result.status
    end

    test "#update_deprecations deletes existing deprecated_references files when all reference violations are resolved" do
      use_template(:minimal)
      File.write(to_app_path("deprecated_references.yml"), "fake deprecated references data")
      assert File.exist?(to_app_path("deprecated_references.yml"))

      RunContext.any_instance.stubs(:process_file).returns([])
      parse_run = Packwerk::ParseRun.new(
        relative_file_set: Set.new(["path/of/exile.rb"]),
        run_context: RunContext.from_configuration(Configuration.from_path)
      )
      parse_run.update_deprecations

      refute File.exist?(to_app_path("deprecated_references.yml"))
    end

    test "#update_deprecations returns exit code 1 when there are offenses" do
      use_template(:minimal)
      offense = Offense.new(file: "path/of/exile.rb", message: "something")
      run_context = RunContext.from_configuration(Configuration.from_path)
      run_context.stubs(:process_file).returns([offense])
      OffenseCollection.any_instance.expects(:dump_deprecated_references_files).once

      parse_run = Packwerk::ParseRun.new(
        relative_file_set: Set.new(["path/of/exile.rb"]),
        run_context: run_context
      )
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
      use_template(:minimal)
      run_context = RunContext.from_configuration(Configuration.new({ "parallel" => false }))
      package = run_context.package_set.first

      offense = ReferenceOffense.new(
        reference: build_reference(source_package: package),
        violation_type: ViolationType::Privacy
      )
      run_context.stubs(:process_file).returns([offense])

      DeprecatedReferences.any_instance.stubs(:listed?).returns(true)
      out = StringIO.new
      parse_run = Packwerk::ParseRun.new(
        relative_file_set: Set.new(["some/path.rb"]),
        run_context: run_context,
        progress_formatter: Packwerk::Formatters::ProgressFormatter.new(out)
      )
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

    test "#check result has failure status when stale violations exist" do
      use_template(:minimal)
      DeprecatedReferences.any_instance.stubs(:listed?).returns(true)
      OffenseCollection.any_instance.stubs(:stale_violations?).returns(true)
      run_context = RunContext.from_configuration(Configuration.new({ "parallel" => false }))
      out = StringIO.new
      parse_run = Packwerk::ParseRun.new(
        relative_file_set: Set.new(["components/sales/app/models/order.rb"]),
        run_context: run_context,
        progress_formatter: Packwerk::Formatters::ProgressFormatter.new(out)
      )
      result = parse_run.check

      expected_output = <<~EOS
        📦 Packwerk is inspecting 1 file
        \\.
        📦 Finished in \\d+\\.\\d+ seconds
      EOS
      assert_match(/#{expected_output}/, out.string)

      expected_message = <<~EOS
        No offenses detected
        There were stale violations found, please run `packwerk update-deprecations`
      EOS

      refute result.status
      assert_equal expected_message, result.message
    end

    test "runs in parallel" do
      use_template(:minimal)
      run_context = RunContext.from_configuration(Configuration.new)
      package = run_context.package_set.first
      offense = ReferenceOffense.new(
        reference: build_reference(source_package: package),
        violation_type: ViolationType::Privacy
      )
      offense2 = ReferenceOffense.new(
        reference: build_reference(path: "components/sales/app/models/order.rb", source_package: package),
        violation_type: ViolationType::Privacy
      )
      file_set = Set.new([
        "components/sales/app/models/order.rb",
        "components/sales/app/models/sales/order.rb",
      ])
      run_context.stubs(:process_file).returns([offense]).returns([offense2])

      parse_run = Packwerk::ParseRun.new(relative_file_set: file_set, run_context: run_context)
      result = parse_run.check
      refute result.status
      assert_match(/2 offenses detected/, result.message)
    end
  end
end
