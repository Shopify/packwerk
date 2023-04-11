# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  module Generators
    class RootPackageTest < Minitest::Test
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
        @generated_file_path = File.join(@temp_dir, "package.yml")
      end

      teardown do
        FileUtils.remove_entry(@temp_dir)
      end

      test ".generate creates a package.yml file" do
        success = Generators::RootPackage.generate(root: @temp_dir, shell: @shell)
        assert(File.exist?(@generated_file_path))
        assert success
        assert_includes @string_io.string, "root package generated"
      end

      test ".generate does not create a package.yml file if package.yml already exists" do
        File.open(File.join(@temp_dir, "package.yml"), "w") do |_f|
          success = Generators::RootPackage.generate(root: @temp_dir, shell: @shell)
          assert success
          assert_includes @string_io.string, "Root package already exists"
        end
      end
    end
  end
end
