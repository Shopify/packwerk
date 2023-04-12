# typed: strict
# frozen_string_literal: true

module Packwerk
  class Cli
    class BaseCommand
      extend T::Sig

      sig { params(cli: Cli, args: T::Array[String]).void }
      def initialize(cli, args)
        @cli = cli
        @args = args
      end
    end
  end
end
