# typed: strict
# frozen_string_literal: true

module Packwerk
  class Cli
    class BaseCommand
      extend T::Sig
      extend T::Helpers
      abstract!

      class << self
        extend T::Sig

        sig { params(names: String).void }
        def register_cli_command(*names)
          Cli.register_command(self, names)
        end
      end

      sig { params(cli: Cli, args: T::Array[String]).void }
      def initialize(cli, args)
        @cli = cli
        @args = args
      end

      sig { abstract.returns(Result) }
      def run; end

      private

      sig { returns(Cli) }
      attr_reader :cli

      sig { returns(T::Array[String]) }
      attr_reader :args
    end
  end
end
