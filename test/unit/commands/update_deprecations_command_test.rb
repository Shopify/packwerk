# frozen_string_literal: true
require "test_helper"
require "rails_test_helper"
require "packwerk/commands/update_deprecations_command"

module Packwerk
  module Commands
    class UpdateDeprecationsCommandTest < Minitest::Test
      test "#run returns success when there are no offenses" do
        run_context = RunContext.new(root_path: ".", load_paths: ".")
        run_context.stubs(:process_file).returns([])

        string_io = StringIO.new
        style = OutputStyles::Plain.new

        RunContext.stubs(from_configuration: run_context)

        update_deprecations_command = Commands::UpdateDeprecationsCommand.new(
          configuration: Configuration.from_path,
          files: ["path/of/exile.rb"],
          offenses_formatter: Formatters::OffensesFormatter.new(style: style),
          progress_formatter: Formatters::ProgressFormatter.new(string_io, style: style),
        )
        result = update_deprecations_command.run

        expected_message = "✅ `deprecated_references.yml` has been updated."
        assert_equal expected_message, result.message
        assert result.status
      end

      test "#run returns exit code 1 when there are offenses" do
        source_package = Package.new(name: ".", config: {})
        destination_package = Package.new(name: "destination_package", config: {})
        reference =
          Reference.new(
            source_package,
            "some/path.rb",
            ConstantDiscovery::ConstantContext.new("::SomethingSpecial", "some/location.rb", destination_package, false)
          )
        offense = ReferenceOffense.new(reference: reference, violation_type: ViolationType::Privacy)
        run_context = RunContext.new(root_path: ".", load_paths: ".")
        run_context.stubs(:process_file).returns([offense])
        CacheDeprecatedReferences.any_instance.stubs(:dump_deprecated_references_files).returns(nil)

        string_io = StringIO.new
        style = OutputStyles::Plain.new

        RunContext.stubs(from_configuration: run_context)

        update_deprecations_command = Commands::UpdateDeprecationsCommand.new(
          configuration: Configuration.from_path,
          files: ["path/of/exile.rb"],
          offenses_formatter: Formatters::OffensesFormatter.new(style: style),
          progress_formatter: Formatters::ProgressFormatter.new(string_io, style: style),
        )
        result = update_deprecations_command.run

        expected_message = "✅ `deprecated_references.yml` has been updated."
        assert_equal expected_message, result.message
        refute result.status
      end
    end
  end
end
