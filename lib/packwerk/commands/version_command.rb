# typed: strict
# frozen_string_literal: true

module Packwerk
  module Commands
    class VersionCommand < BaseCommand
      extend T::Sig

      description "output packwerk version"

      # @override
      #: -> bool
      def run
        out.puts(Packwerk::VERSION)
        true
      end
    end
  end
end
