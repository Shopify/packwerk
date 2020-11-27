# typed: false
# frozen_string_literal: true

require "test_helper"
require "packwerk/application_validator"

# make sure PrivateThing.constantize succeeds to pass the privacy validity check
require "fixtures/skeleton/components/timeline/app/models/private_thing.rb"

# make sure the application has a chance to load its inflections
require "fixtures/skeleton/config/environment"

module Packwerk
  class ApplicationValidatorTest < Minitest::Test
    include RailsApplicationFixtureHelper

    setup do
      setup_application_fixture
    end

    teardown do
      teardown_application_fixture
    end

    test "validity" do
      use_template(:skeleton)

      result = validator.check_all

      assert result.ok?, result.error_value
    end

    test "check_package_manifests_for_privacy returns an error for unresolvable privatized constants" do
      use_template(:skeleton)
      ConstantResolver.expects(:new).returns(stub("resolver", resolve: nil))

      result = validator.check_package_manifests_for_privacy

      refute result.ok?, result.error_value
    end

    test "check_inflection_file returns error for mismatched inflections.yml file" do
      use_template(:skeleton)
      merge_into_app_yaml_file("different_inflections.yml", { "acronym" => %w(TLA WTF LOL) })
      merge_into_app_yaml_file("packwerk.yml", { "inflections_file" => "different_inflections.yml" })

      result = validator.check_inflection_file

      refute result.ok?, result.error_value
      assert_match(
        /Inflections specified in #{to_app_path('different_inflections.yml')} don't line up/,
        result.error_value
      )
    end

    test "check_inflection_file works for custom inflections file with inflections matching ActiveSupport" do
      use_template(:skeleton)
      inflections = ActiveSupport::Inflector.inflections.deep_dup
      Packwerk::Inflections::Custom.new(
        Rails.root.join("custom_inflections.yml")
      ).apply_to(inflections)

      ActiveSupport::Inflector.expects(:inflections).returns(inflections).at_least_once

      result = validator.check_inflection_file

      assert result.ok?, result.error_value
    end

    def validator
      @application_validator ||= Packwerk::ApplicationValidator.new(
        config_file_path: config.config_path,
        configuration: config
      )
    end
  end
end
