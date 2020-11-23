# typed: false
# frozen_string_literal: true

require "test_helper"

module Packwerk
  module Formatters
    class OffensesFormatterTest < Minitest::Test
      setup do
        @string_io = StringIO.new
        @offenses_formatter = OffensesFormatter.new(@string_io)
      end

      test "#show_offenses prints No offenses detected when there are no offenses" do
        @offenses_formatter.show_offenses([])
        assert_match "No offenses detected 🎉", @string_io.string
      end

      test "#show_offenses prints the amount of files when there are offenses" do
        offense = Offense.new(file: "first_file.rb", message: "an offense")
        another_offense = Offense.new(file: "second_file.rb", message: "another offense")
        @offenses_formatter.show_offenses([offense, another_offense])
        assert_match "2 offenses detected", @string_io.string
      end

      test "#show_offenses prints the files with offenses" do
        offense = Offense.new(file: "first_file.rb", message: "an offense")
        another_offense = Offense.new(file: "second_file.rb", message: "another offense")
        @offenses_formatter.show_offenses([offense, another_offense])
        assert_match offense.to_s, @string_io.string
        assert_match another_offense.to_s, @string_io.string
      end
    end
  end
end
