# typed: strict
# frozen_string_literal: true

module Packwerk
  class Cli
    class VersionCommand
      extend T::Sig

      sig { returns(Result) }
      def run
        Result.new(message: Packwerk::VERSION, status: true)
      end
    end

    private_constant :VersionCommand
  end
end
