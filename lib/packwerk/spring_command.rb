# typed: strict
# frozen_string_literal: true

require "spring/commands"
require "sorbet-runtime"

module Packwerk
  class SpringCommand
    extend T::Sig

    #: (untyped args) -> String
    def env(args)
      # Packwerk needs to run in a test environment, which has a set of autoload paths that are
      # often a superset of the dev/prod paths (for example, test/support/helpers)
      "test"
    end

    #: -> String
    def exec_name
      "packwerk"
    end

    #: -> String
    def gem_name
      "packwerk"
    end

    #: -> bool
    def call
      load(Gem.bin_path(gem_name, exec_name))
    end
  end

  Spring.register_command("packwerk", SpringCommand.new)
end
