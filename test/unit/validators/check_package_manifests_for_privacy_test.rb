# typed: true
# frozen_string_literal: true

require "test_helper"

# make sure PrivateThing.constantize succeeds to pass the privacy validity check
require "fixtures/skeleton/components/timeline/app/models/private_thing"

module Packwerk
  class CheckPackageManifestsForPrivacyTest < Minitest::Test
    extend T::Sig
    include RailsApplicationFixtureHelper

    setup do
      setup_application_fixture
    end

    teardown do
      teardown_application_fixture
    end

    test "check_all returns an error for invalid enforce_privacy value" do
      use_template(:minimal)
      merge_into_app_yaml_file("package.yml", { "enforce_privacy" => "yes, please." })

      result = Packwerk::ApplicationValidator::CheckPackageManifestsForPrivacy.call(
        validator.package_set,
        config
      )

      refute result.ok?
      assert_match(/Invalid 'enforce_privacy' option/, result.error_value)
    end

    test "check_all returns an error for invalid public_path value" do
      use_template(:minimal)
      merge_into_app_yaml_file("package.yml", { "public_path" => [] })

      result = Packwerk::ApplicationValidator::CheckPackageManifestsForPrivacy.call(
        validator.package_set,
        config
      )

      refute result.ok?
      assert_match(/'public_path' option must be a string/, result.error_value)
    end

    test "check_package_manifests_for_privacy returns an error for unresolvable privatized constants" do
      use_template(:skeleton)
      ConstantResolver.expects(:new).returns(stub("resolver", resolve: nil))

      result = Packwerk::ApplicationValidator::CheckPackageManifestsForPrivacy.call(
        validator.package_set,
        config
      )

      refute result.ok?, result.error_value
      assert_match(
        /'::PrivateThing', listed in #{to_app_path('components\/timeline\/package.yml')}, could not be resolved/,
        result.error_value
      )
      assert_match(
        /Add a private_thing.rb file/,
        result.error_value
      )
    end

    test "check_package_manifests_for_privacy returns an error for privatized constants in other packages" do
      use_template(:skeleton)
      context = ConstantResolver::ConstantContext.new("::PrivateThing", "private_thing.rb")

      ConstantResolver.expects(:new).returns(stub("resolver", resolve: context))

      result = Packwerk::ApplicationValidator::CheckPackageManifestsForPrivacy.call(
        validator.package_set,
        config
      )

      refute result.ok?, result.error_value
      assert_match(
        %r{'::PrivateThing' is declared as private in the 'components/timeline' package},
        result.error_value
      )
      assert_match(
        /but appears to be defined\sin the '.' package/,
        result.error_value
      )
    end

    test "check_package_manifests_for_privacy returns an error for constants without `::` prefix" do
      use_template(:minimal)
      merge_into_app_yaml_file("package.yml", { "enforce_privacy" => ["::PrivateThing", "OtherThing"] })

      result = Packwerk::ApplicationValidator::CheckPackageManifestsForPrivacy.call(
        validator.package_set,
        config
      )

      refute result.ok?, result.error_value
      assert_match(
        /'OtherThing', listed in the 'enforce_privacy' option in .*package.yml, is invalid./,
        result.error_value
      )
      assert_match(
        /Private constants need to be prefixed with the top-level namespace operator `::`/,
        result.error_value
      )
    end

    sig { returns(Packwerk::ApplicationValidator) }
    def validator
      @application_validator ||= Packwerk::ApplicationValidator.new(
        config_file_path: config.config_path,
        configuration: config,
        environment: "test"
      )
    end
  end
end
