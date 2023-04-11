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

      private

      sig { params(thor_group_class: T.class_of(Commands::Command)).void }
      def register_group_as_command(thor_group_class)
        register(
          thor_group_class,
          thor_group_class.command_name,
          thor_group_class.usage,
          thor_group_class.description,
        )
      end
    end

    register_group_as_command Commands::Check
    register_group_as_command Commands::UpdateTodo
    register_group_as_command Commands::Init
    register_group_as_command Commands::Validate

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

    desc "version", "output packwerk version"
    sig { returns(T::Boolean) }
    def version
      say(Packwerk::VERSION)
      true
    end
  end

  private_constant(:CommandLine)
end
