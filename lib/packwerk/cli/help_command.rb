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
          #{command_help_lines}
        USAGE

        true
      end

      private

      sig { returns(String) }
      def command_help_lines
        CommandRegistry.all.map do |command|
          "  #{command.name} - #{command.help}"
        end.join("\n")
      end
    end
  end
end
