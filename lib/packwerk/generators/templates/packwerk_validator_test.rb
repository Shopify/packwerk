# typed: false
# frozen_string_literal: true

require "test_helper"
require "packwerk"

# This test is necessary to make sure that the package system is working correctly
class PackwerkValidatorTest < Minitest::Test
  def test_the_application_is_correctly_set_up_for_the_package_system
    assert(Packwerk::Cli.new.execute_command(["validate"]))
  end
end
