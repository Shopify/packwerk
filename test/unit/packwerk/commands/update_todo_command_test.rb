# typed: true
# frozen_string_literal: true

require "test_helper"
require "support/rails_test_helper"

module Packwerk
  module Commands
    class UpdateTodoCommandTest < Minitest::Test
      include FactoryHelper
      include ApplicationFixtureHelper

      setup do
        setup_application_fixture
      end

      teardown do
        teardown_application_fixture
      end

      test "#run returns success when there are no offenses" do
        use_template(:minimal)
        RunContext.any_instance.stubs(:process_file).returns([])
        OffenseCollection.any_instance.expects(:dump_package_todo_files).once

        FilesForProcessing.any_instance.stubs(:files).returns(Set.new(["path/of/exile.rb"]))
        out = StringIO.new
        configuration = Configuration.from_path
        update_command = UpdateTodoCommand.new(
          [],
          configuration: configuration,
          out: out,
          err_out: StringIO.new,
          progress_formatter: Formatters::ProgressFormatter.new(out),
          offenses_formatter: configuration.offenses_formatter
        )

        result = update_command.run

        expected_output = <<~EOS
          No offenses detected
          ✅ `package_todo.yml` has been updated.
        EOS
        assert_match(/#{expected_output}/, out.string)
        assert result
      end

      test "#run returns exit code 1 when there are offenses" do
        use_template(:minimal)
        offense = Offense.new(file: "path/of/exile.rb", message: "something")
        RunContext.any_instance.stubs(:process_file).returns([offense])
        OffenseCollection.any_instance.expects(:dump_package_todo_files).once

        FilesForProcessing.any_instance.stubs(:files).returns(Set.new(["path/of/exile.rb"]))
        out = StringIO.new
        configuration = Configuration.from_path
        update_command = UpdateTodoCommand.new(
          [],
          configuration: configuration,
          out: out,
          err_out: StringIO.new,
          progress_formatter: Formatters::ProgressFormatter.new(out),
          offenses_formatter: configuration.offenses_formatter
        )

        result = update_command.run

        expected_output = <<~EOS
          path/of/exile.rb
          something

          1 offense detected

          ✅ `package_todo.yml` has been updated.
        EOS
        assert_match(/#{expected_output}/, out.string)
        refute result
      end

      test "#run returns exit code 1 when ran with file args" do
        use_template(:minimal)

        FilesForProcessing.any_instance.stubs(:files).returns(Set.new(["path/of/exile.rb"]))
        FilesForProcessing.any_instance.stubs(:files_specified?).returns(true)
        out = StringIO.new
        configuration = Configuration.from_path
        update_command = UpdateTodoCommand.new(
          [],
          configuration: configuration,
          out: out,
          err_out: StringIO.new,
          progress_formatter: Formatters::ProgressFormatter.new(out),
          offenses_formatter: configuration.offenses_formatter
        )

        result = update_command.run

        expected_output = "⚠️ update-todo must be called without any file arguments."
        assert_match(/#{expected_output}/, out.string)
        refute result
      end

      test "#run cleans up old package_todo files" do
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

        FilesForProcessing.any_instance.stubs(:files)
          .returns(Set.new(["app/models/my_model.rb", "components/sales/app/models/order.rb"]))
        out = StringIO.new
        configuration = Configuration.from_path
        update_command = UpdateTodoCommand.new(
          [],
          configuration: configuration,
          out: out,
          err_out: StringIO.new,
          progress_formatter: Formatters::ProgressFormatter.new(out),
          offenses_formatter: configuration.offenses_formatter
        )

        result = update_command.run

        expected_output = <<~EOS
          No offenses detected
          ✅ `package_todo.yml` has been updated.
        EOS
        assert_match(/#{expected_output}/, out.string)
        assert result

        assert File.exist?("package_todo.yml")
        refute File.exist?("components/sales/package_todo.yml")
      end
    end
  end
end
