# typed: false
# frozen_string_literal: true

require "test_helper"

# make sure the application has a chance to load its inflections
require "fixtures/classic/config/environment"

module Packwerk
  module Classic
    class ResolveConstantDefinitionsTest < Minitest::Test
      include RailsApplicationFixtureHelper

      setup do
        setup_application_fixture
      end

      teardown do
        teardown_application_fixture
      end

      test "#call returns empty array with no resolution offenses" do
        use_template(:minimal)

        result = resolver.call

        assert_empty result
      end

      test "#call returns an offense when constant cannot be resolved" do
        use_template(:classic)
        merge_into_app_yaml_file("packwerk.yml", { "load_paths" => ["components/sales/app/models"] })

        result = resolver.call

        refute_empty result
        assert_equal result.first.message,
          "cannot resolve ::Entry defined in components/sales/app/models/sales/entry.rb"
      end

      test "#call returns an offense when constant defined in wrong file" do
        use_template(:classic)
        merge_into_app_yaml_file("packwerk.yml", { "load_paths" => ["components/platform/app/models"] })

        result = resolver.call

        refute_empty result
        assert_equal result.first.message,
          "expected ::Users to be defined in components/platform/app/models/users.rb"
      end

      def resolver
        @resolver ||= Packwerk::Classic::ResolveConstantDefinitions.new(configuration: config)
      end
    end
  end
end
