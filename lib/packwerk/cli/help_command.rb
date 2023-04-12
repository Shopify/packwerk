# typed: strict
# frozen_string_literal: true

module Packwerk
  class Cli
    class HelpCommand
      extend T::Sig

      sig { params(out: T.any(StringIO, IO)).void }
      def initialize(out:)
        @out = out
      end

      sig { returns(Result) }
      def run
        Result.new(status: true, message: <<~USAGE)
          Usage: #{$PROGRAM_NAME} <subcommand>

          Subcommands:
            init - set up packwerk
            check - run all checks
            update-todo - update package_todo.yml files
            validate - verify integrity of packwerk and package configuration
            version - output packwerk version
            help  - display help information about packwerk
        USAGE
      end
    end

    private_constant :HelpCommand
  end
end
