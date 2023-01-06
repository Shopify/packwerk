# typed: false
# frozen_string_literal: true

require "test_helper"
require "spring/commands"
require "active_support/testing/isolation"

module Packwerk
  class SpringCommandTest < Minitest::Test
    include ActiveSupport::Testing::Isolation

    test "registers command with Spring when loaded" do
      require_command

      command = Spring.command("packwerk")

      assert_not_nil(command, message: "packwerk command not registered with Spring")
      assert_equal("packwerk", command.exec_name)
      assert_equal("packwerk", command.gem_name)
      assert_equal("test", command.env(nil))
    end

    test "disables Sorbet" do
      error = assert_raises(RuntimeError) do
        require_command(ignore_errors: false)
      end

      assert_match(/Set the default checked level earlier./, error.message)
    end

    private

    def require_command(ignore_errors: true)
      require "packwerk/spring_command"
    rescue => error
      raise error unless ignore_errors
    end
  end
end
