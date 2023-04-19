# typed: true
# frozen_string_literal: true

module Packwerk
  module Commands
    extend ActiveSupport::Autoload

    autoload :BaseCommand
    autoload :CheckCommand
    autoload :HelpCommand
    autoload :InitCommand
    autoload :UpdateCommand, "packwerk/commands/update_todo_command"
    autoload :UpdateTodoCommand
    autoload :UsesParseRun
    autoload :ValidateCommand
    autoload :VersionCommand

    class << self
      extend T::Sig

      sig { params(command: String).returns(T.nilable(T.class_of(Commands::BaseCommand))) }
      def class_for(command)
        class_name = command.sub(" ", "_").underscore.classify + "Command"
        if Commands.const_defined?(class_name)
          Commands.const_get(class_name) # rubocop:disable Sorbet/ConstantsFromStrings
        end
      end
    end
  end
end
