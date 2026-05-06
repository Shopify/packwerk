# typed: strict
# frozen_string_literal: true

module Packwerk
  module Commands
    class LazyLoadedEntry
      #: String
      attr_reader :name

      #: (String name, ?aliases: Array[String]) -> void
      def initialize(name, aliases: [])
        @name = name
        @aliases = aliases
      end

      #: -> singleton(BaseCommand)
      def command_class
        classname = @name.sub(" ", "_").underscore.classify + "Command"
        Commands.const_get(classname) # rubocop:disable Sorbet/ConstantsFromStrings
      end

      #: -> String
      def description
        command_class.description
      end

      #: (String name_or_alias) -> bool
      def matches_command?(name_or_alias)
        @name == name_or_alias || @aliases.include?(name_or_alias)
      end
    end

    private_constant :LazyLoadedEntry
  end
end
