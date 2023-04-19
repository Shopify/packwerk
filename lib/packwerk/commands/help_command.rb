# typed: strict
# frozen_string_literal: true

module Packwerk
  module Commands
    class HelpCommand < BaseCommand
      extend T::Sig

      sig { override.returns(Cli::Result) }
      def run
        Cli::Result.new(status: true, print_as_error: true, message: <<~USAGE)
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
  end
end
