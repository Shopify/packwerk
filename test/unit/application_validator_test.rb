# typed: false
# frozen_string_literal: true

require "test_helper"
require "rails_test_helper"

require "packwerk/application_validator"

# make sure PrivateThing.constantize succeeds to pass the privacy validity check
require "fixtures/skeleton/components/timeline/app/models/private_thing.rb"

# make sure the application has a chance to load its inflections
require "fixtures/skeleton/config/environment"

module Packwerk
  class ApplicationValidatorTest < Minitest::Test
    setup do
      @configuration = Packwerk::Configuration.from_path("test/fixtures/skeleton")
    end

    test "validity" do
      application_validator = Packwerk::ApplicationValidator.new(
        config_file_path: @configuration.config_path,
        application_load_paths: @configuration.all_application_autoload_paths,
        configuration: @configuration
      )
      result = application_validator.check_all

      assert result.ok?, result.error_value
    end

    test "returns an error for unresolvable privatized constants" do
      application_validator = Packwerk::ApplicationValidator.new(
        config_file_path: @configuration.config_path,
        application_load_paths: @configuration.all_application_autoload_paths,
        configuration: @configuration
      )
      ConstantResolver.expects(:new).returns(stub("resolver", resolve: nil))

      result = application_validator.check_package_manifests_for_privacy

      refute result.ok?, result.error_value
    end

    test "returns error for mismatched inflections.yml file" do
      config_path = "test/fixtures/skeleton/packwerk.yml"
      configs = YAML.load_file(config_path)
      configs["inflections_file"] = "different_inflections.yml"

      configuration = Packwerk::Configuration.new(configs, config_path: config_path)

      application_validator = Packwerk::ApplicationValidator.new(
        config_file_path: configuration.config_path,
        application_load_paths: configuration.all_application_autoload_paths,
        configuration: configuration
      )

      result = application_validator.check_all

      refute(result.ok?, result.error_value)
    end

    test "works for custom inflections file with inflections matching ActiveSupport" do
      inflections = ActiveSupport::Inflector.inflections.deep_dup
      Packwerk::Inflections::Custom.new(
        Rails.root.join("custom_inflections.yml")
      ).apply_to(inflections)

      ActiveSupport::Inflector.expects(:inflections).returns(inflections).at_least_once

      config_path = "test/fixtures/skeleton/packwerk.yml"
      configs = YAML.load_file(config_path)
      configs["inflections_file"] = "custom_inflections.yml"

      configuration = Packwerk::Configuration.new(configs, config_path: config_path)

      application_validator = Packwerk::ApplicationValidator.new(
        config_file_path: configuration.config_path,
        application_load_paths: configuration.all_application_autoload_paths,
        configuration: configuration
      )

      result = application_validator.check_all

      assert(result.ok?, result.error_value)
    end
  end
end
