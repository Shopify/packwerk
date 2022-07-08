# typed: true
# frozen_string_literal: true

require "spring/commands"

module Packwerk
  class SpringCommand
    def env(*)
      # Packwerk needs to run in a test environment, which has a set of autoload paths that are
      # often a superset of the dev/prod paths (for example, test/support/helpers)
      "test"
    end

    def exec_name
      "packwerk"
    end

    def gem_name
      "packwerk"
    end

    def call
      load(Gem.bin_path(gem_name, exec_name))
    end
  end

  Spring.register_command("packwerk", SpringCommand.new)
end
