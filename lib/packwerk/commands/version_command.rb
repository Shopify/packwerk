# typed: strict
# frozen_string_literal: true

module Packwerk
  module Commands
    class VersionCommand < BaseCommand
      extend T::Sig

      sig { override.returns(Cli::Result) }
      def run
        Cli::Result.new(message: Packwerk::VERSION, status: true)
      end
    end
  end
end
