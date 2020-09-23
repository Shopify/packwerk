# typed: false
# frozen_string_literal: true

require "test_helper"

module Packwerk
  module Generators
    class ApplicationValidationTest < Minitest::Test
      setup do
        @string_io = StringIO.new
        @temp_dir = Dir.mktmpdir
      end

      teardown do
        FileUtils.remove_entry(@temp_dir)
      end

      test ".generate creates a script for packwerk validate if it is for a Rails application" do
        generated_file_path = File.join(@temp_dir, "bin", "packwerk")
        Packwerk::Generators::ApplicationValidation.generate(for_rails_app: true, root: @temp_dir, out: @string_io)

        assert_file_generated(generated_file_path)
      end

      test ".generate does not create a script if one already exists" do
        Dir.mkdir(File.join(@temp_dir, "bin"))
        generated_file_path = File.join(@temp_dir, "bin", "packwerk")

        File.open(generated_file_path, "w") do |_f|
          Packwerk::Generators::ApplicationValidation.generate(for_rails_app: true, root: @temp_dir, out: @string_io)

          assert(File.exist?(generated_file_path))
          assert_includes(@string_io.string, "bin script already exists")
        end
      end

      test ".generate creates a test file if it is not a Rails application" do
        generated_file_path = File.join(@temp_dir, "test", "packwerk_validator_test.rb")
        Packwerk::Generators::ApplicationValidation.generate(for_rails_app: false, root: @temp_dir, out: @string_io)

        assert_file_generated(generated_file_path)
      end

      test ".generate does not create a test file if one already exists" do
        Dir.mkdir(File.join(@temp_dir, "test"))
        generated_file_path = File.join(@temp_dir, "test", "packwerk_validator_test.rb")

        File.open(generated_file_path, "w") do |_f|
          Packwerk::Generators::ApplicationValidation.generate(for_rails_app: false, root: @temp_dir, out: @string_io)

          assert(File.exist?(generated_file_path))
          assert_includes(@string_io.string, "test already exists")
        end
      end

      private

      def assert_file_generated(file_path)
        assert(File.exist?(file_path))
        assert_includes(File.read(file_path), "Packwerk::Cli.new")
      end
    end
  end
end
