# typed: strict
# frozen_string_literal: true

module Packwerk
  class Cli
    class CommandRegistry
      extend T::Sig

      class << self
        extend T::Sig

        sig { params(name: String, aliases: T::Array[String]).void }
        def register(name, aliases: [])
          registry << new(name, aliases: aliases)
        end

        sig { params(name_or_alias: String).returns(T.nilable(T.class_of(Cli::BaseCommand))) }
        def class_for(name_or_alias)
          registry
            .find { |command| command.matches_command?(name_or_alias) }
            &.command_class
        end

        private

        sig { returns(T::Array[CommandRegistry]) }
        def registry
          @registry ||= T.let([], T.nilable(T::Array[CommandRegistry]))
        end
      end

      sig { params(name: String, aliases: T::Array[String]).void }
      def initialize(name, aliases: [])
        @name = name
        @aliases = aliases
      end

      sig { returns(T.class_of(Cli::BaseCommand)) }
      def command_class
        classname = @name.sub(" ", "_").underscore.classify + "Command"
        Cli.const_get(classname) # rubocop:disable Sorbet/ConstantsFromStrings
      end

      sig { params(name_or_alias: String).returns(T::Boolean) }
      def matches_command?(name_or_alias)
        @name == name_or_alias || @aliases.include?(name_or_alias)
      end
    end

    private_constant :CommandRegistry
  end
end
