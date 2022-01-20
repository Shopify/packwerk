# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  module Formatters
    class ProgressFormatterTest < Minitest::Test
      setup do
        @string_io = StringIO.new
        @progress_formatter = ProgressFormatter.new(@string_io)
      end

      test "#started prints the right file size for multiple files" do
        @progress_formatter.started([1, 2, 3, 4, 5])
        assert_match "5", @string_io.string
        assert_match "files", @string_io.string
      end

      test "#started prints the right file size for single files" do
        @progress_formatter.started([1])
        assert_match "1", @string_io.string
        assert_match "file", @string_io.string
      end

      test "#started prints the right file size for no files" do
        @progress_formatter.started([])
        assert_match "0 files", @string_io.string
      end

      test "#started_validation yields control to code block" do
        @progress_formatter.started_validation do
          @string_io.puts("This block has been run")
        end

        assert_match "This block has been run", @string_io.string
      end

      test "#mark_as_inspected prints a dot" do
        @progress_formatter.mark_as_inspected
        assert_equal ".", @string_io.string
      end

      test "#mark_as_failed prints an E" do
        @progress_formatter.mark_as_failed
        assert_equal "E", @string_io.string
      end

      test "#finished prints the correct time" do
        @progress_formatter.finished(1.1234)
        assert_match "1.12", @string_io.string
      end
    end
  end
end
