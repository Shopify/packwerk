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

    test "#call returns empty array with no resolution offenses" do
      use_template(:minimal)

      result = validation_run.find_offenses

      assert_empty result.new_violations
    end

    test "#call returns an offense when constant cannot be resolved" do
      use_template(:classic)
      merge_into_app_yaml_file("packwerk.yml", { "load_paths" => ["components/sales/app/models"] })

      result = validation_run.find_offenses

      refute_empty result.new_violations
      assert_equal result.new_violations.first.message, <<~EOS
        ::Entry is defined in components/sales/app/models/sales/entry.rb but cannot be resolved by Zeitwerk.
        Please verify that the load path for ::Entry is correct and doesn't contain a missing inflection.
        EOS
    end

    test "#call returns an offense when constant defined in wrong file" do
      use_template(:classic)
      merge_into_app_yaml_file("packwerk.yml", { "load_paths" => ["components/platform/app/models"] })

      result = validation_run.find_offenses

      refute_empty result.new_violations
      assert_equal result.new_violations.first.message, <<~EOS
        Expected ::Users to be defined in components/platform/app/models/users.rb,
        but found a definition in components/platform/app/models/users/user.rb.
        Please verify that the load path for ::Users is correct.
        EOS
    end

    def validation_run
      @validation_run ||= ZeitwerkValidationRun.new(configuration: config)
    end
  end
end
