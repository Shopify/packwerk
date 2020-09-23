# typed: false
# frozen_string_literal: true

require "test_helper"

module Packwerk
  module Generators
    class InflectionsFileTest < Minitest::Test
      setup do
        @string_io = StringIO.new
        @temp_dir = Dir.mktmpdir
      end

      teardown do
        FileUtils.remove_entry(@temp_dir)
      end

      test ".generate creates an inflections.yml file only if inflections.rb exists" do
        File.open(File.join(@temp_dir, "inflections.rb"), "w") do |_f|
          generated_file_path = File.join(@temp_dir, "config", "inflections.yml")
          success = Packwerk::Generators::InflectionsFile.generate(root: @temp_dir, out: @string_io)
          assert(File.exist?(generated_file_path))
          assert success
        end
      end

      test ".generate does not create an inflections.yml file if inflections.rb doesn't exists" do
        generated_file_path = File.join(@temp_dir, "config", "inflections.yml")
        success = Packwerk::Generators::InflectionsFile.generate(root: @temp_dir, out: @string_io)
        refute(File.exist?(generated_file_path))
        assert success
      end

      test ".generate does not create an inflections.yml file if inflections.yml already exists" do
        File.open(File.join(@temp_dir, "inflections.yml"), "w") do |_f|
          generated_file_path = File.join(@temp_dir, "config", "inflections.yml")
          success = Packwerk::Generators::InflectionsFile.generate(root: @temp_dir, out: @string_io)
          refute(File.exist?(generated_file_path))
          assert success
        end
      end
    end
  end
end
