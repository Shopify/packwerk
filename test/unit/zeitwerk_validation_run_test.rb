# typed: false
# frozen_string_literal: true

require "test_helper"

# make sure the application has a chance to load its inflections
require "fixtures/classic/config/environment"

module Packwerk
  class ZeitwerkValidationRunTest < Minitest::Test
    include RailsApplicationFixtureHelper

    setup do
      setup_application_fixture
    end

    teardown do
      teardown_application_fixture
    end

    test "#find_offenses returns empty array with no resolution offenses" do
      use_template(:minimal)

      result = validation_run.find_offenses

      assert_empty result.new_violations
    end

    test "#find_offenses returns an offense when constant cannot be resolved" do
      use_template(:classic)
      merge_into_app_yaml_file("packwerk.yml", { "load_paths" => ["components/sales/app/models"] })

      result = validation_run.find_offenses

      message = <<~EOS
        ::Entry is defined in components/sales/app/models/sales/entry.rb but cannot be resolved by Zeitwerk.
        Please verify that the load path for ::Entry is correct and doesn't contain a missing inflection.
      EOS

      refute_empty result.new_violations
      assert_equal message, result.new_violations.first.message
    end

    test "#find_offenses returns an offense when constant defined in wrong file" do
      use_template(:classic)
      merge_into_app_yaml_file("packwerk.yml", { "load_paths" => ["components/platform/app/models"] })

      result = validation_run.find_offenses

      message = <<~EOS
        Expected ::Users to be defined in components/platform/app/models/users.rb,
        but found a definition in components/platform/app/models/users/user.rb.
        Please verify that the load path for ::Users is correct.
      EOS

      refute_empty result.new_violations
      assert_equal message, result.new_violations.first.message
    end

    test "#detect_zeitwerk_violations returns expected Result when stale violations present" do
      use_template(:classic)

      OffenseCollection.any_instance.stubs(:stale_zeitwerk_violations?).returns(true)
      result = validation_run.validate_zeitwerk

      message = <<~EOS
        No offenses detected
        There were stale Zeitwerk violations found, please run `packwerk update-zeitwerk-violations`
      EOS

      assert_equal message, result.message
      refute result.status
    end

    def validation_run
      @validation_run ||= ZeitwerkValidationRun.new(configuration: config)
    end
  end
end
