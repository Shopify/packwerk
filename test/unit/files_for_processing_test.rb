# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class FilesForProcessingTest < Minitest::Test
    def setup
      @package_path = "components/sales"
      @configuration = ::Packwerk::Configuration.from_path("test/fixtures/skeleton")
    end

    test "fetch with custom paths includes only include glob in custom paths" do
      files = Dir.chdir("test/fixtures/skeleton") do
        ::Packwerk::FilesForProcessing.fetch(relative_file_paths: [@package_path], configuration: @configuration)
      end
      included_file_pattern = File.join(@package_path, "**/*.rb")
      assert_all_match(files, [included_file_pattern])
    end

    test "fetch with custom paths excludes the exclude glob in custom paths" do
      files = ::Packwerk::FilesForProcessing.fetch(relative_file_paths: [@package_path], configuration: @configuration)
      excluded_file_pattern = File.join(@configuration.root_path, @package_path, "**/temp.rb")

      refute_any_match(files, [excluded_file_pattern])
    end

    test "fetch with no custom paths includes only include glob across codebase" do
      files = ::Packwerk::FilesForProcessing.fetch(relative_file_paths: [], configuration: @configuration)

      assert_all_match(files, @configuration.include)
    end

    test "fetch with no custom paths excludes the exclude glob across codebase" do
      files = ::Packwerk::FilesForProcessing.fetch(relative_file_paths: [], configuration: @configuration)
      excluded_file_patterns = @configuration.exclude.map { |pattern| File.join(@configuration.root_path, pattern) }

      refute_any_match(files, Set.new(excluded_file_patterns))
    end

    test "fetch does not return duplicated file paths" do
      files = ::Packwerk::FilesForProcessing.fetch(relative_file_paths: [], configuration: @configuration)
      assert_equal files, Set.new(files)
    end

    test "fetch with custom paths without ignoring nested packages includes only include glob in custom paths including nested package files" do
      files = ::Packwerk::FilesForProcessing.fetch(
        relative_file_paths: ["."],
        configuration: @configuration,
        ignore_nested_packages: false
      )

      assert_all_match(files, Set.new(@configuration.include))
    end

    test "fetch with no custom paths ignoring nested packages includes only include glob across codebase" do
      files = Dir.chdir("test/fixtures/skeleton") do
        ::Packwerk::FilesForProcessing.fetch(
          relative_file_paths: [],
          configuration: @configuration,
          ignore_nested_packages: true
        )
      end

      assert_all_match(files, @configuration.include)
    end

    test "fetch with custom paths ignoring nested packages includes only include glob in custom paths without nested package files" do
      files = ::Packwerk::FilesForProcessing.fetch(
        relative_file_paths: ["."],
        configuration: @configuration,
        ignore_nested_packages: true
      )

      refute_any_match(files, Set.new([File.join(@configuration.root_path, "components/sales", "**/*.rb")]))
      refute_any_match(files, Set.new([File.join(@configuration.root_path, "components/timeline", "**/*.rb")]))
    end

    test "fetch with custom paths for files includes only include glob in custom paths" do
      files = ::Packwerk::FilesForProcessing.fetch(
        relative_file_paths: [
          "components/sales/app/models/order.rb",
          "components/sales/app/views/order.html.erb",
        ],
        configuration: @configuration
      )

      included_file_patterns = @configuration.include

      assert_all_match(files, included_file_patterns)
    end

    private

    def assert_all_match(files, patterns)
      unmatched_files =
        files.reject do |file|
          patterns.any? do |pattern|
            File.fnmatch?(pattern, file, File::FNM_EXTGLOB)
          end
        end

      assert_empty(unmatched_files, "some files did not match inclusion patterns, #{patterns}")
    end

    def refute_any_match(files, patterns)
      matched_files =
        files.select do |file|
          patterns.any? do |pattern|
            File.fnmatch?(pattern, file, File::FNM_EXTGLOB)
          end
        end

      assert_empty(matched_files, "some files matched exclusion patterns, #{patterns}")
    end
  end
end
