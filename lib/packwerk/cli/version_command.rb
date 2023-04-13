# typed: strict
# frozen_string_literal: true

module Packwerk
  class Cli
    class VersionCommand < BaseCommand
      extend T::Sig

      register_cli_command "version"

      sig { override.returns(Result) }
      def run
        Result.new(message: Packwerk::VERSION, status: true)
      end
    end

    private_constant :VersionCommand
  end
end
