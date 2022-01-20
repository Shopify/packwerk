# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  module Formatters
    class OffensesFormatterTest < Minitest::Test
      setup do
        @offenses_formatter = OffensesFormatter.new
      end

      test "#show_offenses prints No offenses detected when there are no offenses" do
        assert_match "No offenses detected", @offenses_formatter.show_offenses([])
      end

      test "#show_offenses prints the amount of files when there are offenses" do
        offense = Offense.new(file: "first_file.rb", message: "an offense")
        another_offense = Offense.new(file: "second_file.rb", message: "another offense")
        assert_match "2 offenses detected", @offenses_formatter.show_offenses([offense, another_offense])
      end

      test "#show_offenses prints the files with offenses" do
        offense = Offense.new(file: "first_file.rb", message: "an offense")
        another_offense = Offense.new(file: "second_file.rb", message: "another offense")
        assert_match offense.to_s, @offenses_formatter.show_offenses([offense, another_offense])
        assert_match another_offense.to_s, @offenses_formatter.show_offenses([offense, another_offense])
      end
    end
  end
end
