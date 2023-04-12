# typed: strict
# frozen_string_literal: true

module Packwerk
  class Cli
    class VersionCommand
      extend T::Sig

      sig { params(out: T.any(StringIO, IO)).void }
      def initialize(out:)
        @out = out
      end

      sig { returns(T::Boolean) }
      def run
        @out.puts(Packwerk::VERSION)
        true
      end
    end

    private_constant :VersionCommand
  end
end