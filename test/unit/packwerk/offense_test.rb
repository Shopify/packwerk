# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class OffenseTest < Minitest::Test
    setup do
      location = Node::Location.new(90, 10)
      file = "components/platform/shop.rb"
      message = "Violation of developer rights"
      @offense = Offense.new(location: location, file: file, message: message)
    end

    test "#to_s returns the location of offense and message" do
      expected_message = "components/platform/shop.rb:90:10\nViolation of developer rights\n"
      assert_equal(expected_message, @offense.to_s)
    end
  end
end
