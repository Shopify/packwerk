# typed: strict
# frozen_string_literal: true

module Packwerk
  class Cli
    class UpdateCommand
      extend T::Sig

      sig { params(parse_run: ParseRun).void }
      def initialize(parse_run:)
        @parse_run = parse_run
      end

      sig { returns(Result) }
      def run
        @parse_run.update_todo
      end
    end

    private_constant :UpdateCommand
  end
end
