# typed: true
# frozen_string_literal: true

require "test_helper"
require "support/rails_test_helper"

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

    test "#update-todo returns success when there are no offenses" do
      use_template(:minimal)
      RunContext.any_instance.stubs(:process_file).returns([])
      OffenseCollection.any_instance.expects(:dump_package_todo_files).once

      parse_run = ParseRun.new(
        relative_file_set: Set.new(["path/of/exile.rb"]),
        configuration: Configuration.from_path
      )
      result = parse_run.update_todo

      assert_equal result.message, <<~EOS
        No offenses detected
        ✅ `package_todo.yml` has been updated.
      EOS
      assert result.status
    end

    test "#update-todo returns exit code 1 when there are offenses" do
      use_template(:minimal)
      offense = Offense.new(file: "path/of/exile.rb", message: "something")
      RunContext.any_instance.stubs(:process_file).returns([offense])
      OffenseCollection.any_instance.expects(:dump_package_todo_files).once

      parse_run = ParseRun.new(
        relative_file_set: Set.new(["path/of/exile.rb"]),
        configuration: Configuration.from_path
      )
      result = parse_run.update_todo

      expected = <<~EOS
        path/of/exile.rb
        something

        1 offense detected

        ✅ `package_todo.yml` has been updated.
      EOS
      assert_equal expected, result.message
      refute result.status
    end

    test "#update-todo returns exit code 1 when ran with file args" do
      use_template(:minimal)

      parse_run = ParseRun.new(
        relative_file_set: Set.new(["path/of/exile.rb"]),
        file_set_specified: true,
        configuration: Configuration.from_path
      )
      result = parse_run.update_todo

      expected = "⚠️ update-todo must be called without any file arguments."
      assert_equal expected, result.message
      refute result.status
    end

    test "#update_todo cleans up old package_todo files" do
      use_template(:minimal)

      FileUtils.mkdir_p("app/models")
      File.write("app/models/my_model.rb", <<~YML.strip)
        class MyModel
          def something
            Order
          end
        end
      YML

      File.write("package_todo.yml", <<~YML.strip)
        ---
        "components/sales":
          "::Order":
            violations:
            - dependency
            files:
            - app/models/my_model.rb
      YML

      File.write("components/sales/package_todo.yml", <<~YML.strip)
        ---
        "components/destination":
          "::SomeName":
            violations:
            - dependency
            files:
            - a/b/c.rb
      YML

      parse_run = ParseRun.new(
        relative_file_set: Set.new(["app/models/my_model.rb", "components/sales/app/models/order.rb"]),
        configuration: Configuration.from_path
      )
      result = parse_run.update_todo

      expected = <<~EOS
        No offenses detected
        ✅ `package_todo.yml` has been updated.
      EOS
      assert_equal expected, result.message
      assert result.status

      assert File.exist?("package_todo.yml")
      refute File.exist?("components/sales/package_todo.yml")
    end
  end
end
