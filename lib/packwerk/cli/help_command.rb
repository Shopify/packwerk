# typed: strict
# frozen_string_literal: true

module Packwerk
  class Cli
    class HelpCommand < BaseCommand
      extend T::Sig

      sig { override.returns(T::Boolean) }
      def run
        @err_out.puts(<<~USAGE)
          Usage: #{$PROGRAM_NAME} <subcommand>

          Subcommands:
            init - set up packwerk
            check - run all checks
            update-todo - update package_todo.yml files
            validate - verify integrity of packwerk and package configuration
            version - output packwerk version
            help  - display help information about packwerk
        USAGE

        true
      end
    end
  end
end
