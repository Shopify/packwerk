# frozen_string_literal: true
require "test_helper"
require "rails_test_helper"
require "packwerk/commands/update_deprecations_command"

module Packwerk
  module Commands
    class UpdateDeprecationsCommandTest < Minitest::Test
      test "#run returns success when there are no offenses" do
        run_context = stub
        run_context.stubs(:process_file).returns([])

        string_io = StringIO.new
        style = OutputStyles::Plain

        RunContext.stubs(from_configuration: run_context)

        update_deprecations_command = Commands::UpdateDeprecationsCommand.new(
          configuration: Configuration.from_path,
          files: ["path/of/exile.rb"],
          offenses_formatter: Formatters::OffensesFormatter.new(string_io, style: style),
          progress_formatter: Formatters::ProgressFormatter.new(string_io, style: style),
        )
        result = update_deprecations_command.run

        assert_equal result.message, "✅ `deprecated_references.yml` has been updated."
        assert result.status
      end

      test "#run returns exit code 1 when there are offenses" do
        offense = Offense.new(file: "path/of/exile.rb", message: "something")
        run_context = stub
        run_context.stubs(:process_file).returns([offense])

        string_io = StringIO.new
        style = OutputStyles::Plain

        RunContext.stubs(from_configuration: run_context)

        update_deprecations_command = Commands::UpdateDeprecationsCommand.new(
          configuration: Configuration.from_path,
          files: ["path/of/exile.rb"],
          offenses_formatter: Formatters::OffensesFormatter.new(string_io, style: style),
          progress_formatter: Formatters::ProgressFormatter.new(string_io, style: style),
        )
        result = update_deprecations_command.run

        assert_equal result.message, "✅ `deprecated_references.yml` has been updated."
        refute result.status
      end
    end
  end
end
