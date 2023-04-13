# typed: strict
# frozen_string_literal: true

module Packwerk
  class Cli
    class CheckCommand < BaseCommand
      extend T::Sig
      include UsesParseRun

      register_cli_command "check"

      sig { override.returns(Result) }
      def run
        parse_run.check
      end
    end

    private_constant :CheckCommand
  end
end
