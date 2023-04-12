# typed: strict
# frozen_string_literal: true

module Packwerk
  class Cli
    class UpdateCommand < BaseCommand
      extend T::Sig
      include UsesParseRun

      sig { override.returns(Result) }
      def run
        parse_run.update_todo
      end
    end

    private_constant :UpdateCommand
  end
end
