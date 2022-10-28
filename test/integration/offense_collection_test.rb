# typed: true
# frozen_string_literal: true

require "test_helper"
require "rails_test_helper"

module Packwerk
  module Integration
    class OffenseCollectionTest < Minitest::Test
      include ApplicationFixtureHelper
      include FactoryHelper

      setup do
        setup_application_fixture
        use_template(:blank)
        @offense_collection = OffenseCollection.new(app_dir)
      end

      teardown do
        teardown_application_fixture
      end

      test "#add_violation for two instances of the same logical package amalgamates both offenses" do
        offense1 = ReferenceOffense.new(
          reference: build_reference(
            constant_name: "::Foo",
            source_package: Package.new(name: ".", config: nil)
          ),
          message: "some message",
          violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE
        )
        offense2 = ReferenceOffense.new(
          reference: build_reference(
            constant_name: "::Bar",
            source_package: Package.new(name: ".", config: nil)
          ),
          message: "some message",
          violation_type: ReferenceChecking::Checkers::DependencyChecker::VIOLATION_TYPE
        )
        @offense_collection.add_offense(offense1)
        @offense_collection.add_offense(offense2)
        @offense_collection.dump_package_todo_files

        expected = {
          "components/destination" => {
            "::Bar" => { "violations" => ["dependency"], "files" => ["some/path.rb"] },
            "::Foo" => { "violations" => ["dependency"], "files" => ["some/path.rb"] },
          },
        }
        assert_equal expected, YAML.load_file("package_todo.yml")
      end
    end
  end
end
