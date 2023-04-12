# typed: strict
# frozen_string_literal: true

module Packwerk
  class Cli
    class CheckCommand < BaseCommand
      extend T::Sig
      include UsesParseRun

      sig { override.returns(Result) }
      def run
        parse_run.check
      end
    end

    private_constant :CheckCommand
  end
end
