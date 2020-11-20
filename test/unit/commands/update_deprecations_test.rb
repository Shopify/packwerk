# frozen_string_literal: true
require "test_helper"
require "rails_test_helper"
require "packwerk/commands/update_deprecations"

module Packwerk
  module Commands
    class UpdateDeprecationsTest < Minitest::Test
      test "#run updates deprecated_references.yml file" do
        run_context = stub
        run_context.stubs(:process_file).returns([])

        string_io = StringIO.new
        style = OutputStyles::Plain

        RunContext.stubs(from_configuration: run_context)

        update_deprecations_command = Commands::UpdateDeprecations.new(
          out: string_io,
          files: ["path/of/exile.rb"],
          configuration: Configuration.from_path,
          progress_formatter: Formatters::ProgressFormatter.new(string_io, style: style),
          style: style
        )

        assert update_deprecations_command.run
        assert_includes string_io.string, "✅ `deprecated_references.yml` has been updated."
      end
    end
  end
end
