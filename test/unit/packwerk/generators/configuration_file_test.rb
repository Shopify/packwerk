# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  module Generators
    class ConfigurationFileTest < Minitest::Test
      setup do
        @string_io = StringIO.new
        @shell = Shell.new(
          stdout: @string_io,
          stderr: @string_io,
          environment: "test",
          progress_formatter: Formatters::ProgressFormatter.new(@string_io),
          offenses_formatter: Formatters::DefaultOffensesFormatter.new,
        )
        @temp_dir = Dir.mktmpdir
      end

      teardown do
        FileUtils.remove_entry(@temp_dir)
      end

      test ".generate creates a default configuration file if there were empty load paths array" do
        generated_file_path = File.join(@temp_dir, Configuration::DEFAULT_CONFIG_PATH)
        assert(Generators::ConfigurationFile.generate(root: @temp_dir, shell: @shell))
        assert(File.exist?(generated_file_path))
      end

      test ".generate does not create a configuration file if a file exists" do
        file_path = File.join(@temp_dir, Configuration::DEFAULT_CONFIG_PATH)
        File.open(file_path, "w") do |_f|
          assert(Generators::ConfigurationFile.generate(
            root: @temp_dir,
            shell: @shell
          ))
          assert_includes(@string_io.string, "configuration file already exists")
        end
      end
    end
  end
end
