# typed: false
# frozen_string_literal: true

require "test_helper"
require "spring/commands"

module Packwerk
  class SpringCommandTest < Minitest::Test
    test "registers command with Spring when loaded" do
      capture_io do
        require_command
      end

      command = Spring.command("packwerk")

      assert_not_nil(command, message: "packwerk command not registered with Spring")
      assert_equal("packwerk", command.exec_name)
      assert_equal("packwerk", command.gem_name)
      assert_equal("test", command.env(nil))
    end

    private

    def require_command
      require "packwerk/spring_command"
    end
  end
end
