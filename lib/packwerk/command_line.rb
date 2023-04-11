# typed: strict
# frozen_string_literal: true

module Packwerk
  class CommandLine < Thor
    extend T::Sig
    extend ActiveSupport::Autoload

    class << self
      extend T::Sig

      sig { returns(T::Boolean) }
      def exit_on_failure?
        false
      end
    end

    register(Commands::Check, :check, "", "")
    register(Commands::UpdateTodo, :update_todo, "", "")
    register(Commands::Init, :init, "", "")
    register(Commands::Validate, :validate, "", "")

    sig { returns(T::Boolean) }
    def help
      say_error.puts(<<~USAGE)
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

    desc "Hi", ""
    sig { returns(T::Boolean) }
    def version
      say(Packwerk::VERSION)
      true
    end
  end

  private_constant(:CommandLine)
end
