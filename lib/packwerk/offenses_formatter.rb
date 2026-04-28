# typed: strict
# frozen_string_literal: true

module Packwerk
  module OffensesFormatter
    extend T::Sig
    extend T::Helpers

    abstract!

    class DuplicateFormatterError < StandardError
      extend T::Sig

      #: (String identifier) -> void
      def initialize(identifier)
        super("Cannot have multiple identifiers with the same key (`#{identifier}`)")
      end
    end

    class << self
      extend T::Sig

      #: (Class[top] base) -> void
      def included(base)
        offenses_formatters << base
      end

      #: -> Array[OffensesFormatter]
      def all
        load_defaults
        T.cast(offenses_formatters.map(&:new), T::Array[OffensesFormatter])
      end

      #: (String identifier) -> OffensesFormatter
      def find(identifier)
        formatter_by_identifier(identifier)
      end

      private

      #: -> void
      def load_defaults
        require("packwerk/formatters/default_offenses_formatter")
      end

      #: -> Array[Class[top]]
      def offenses_formatters
        @offenses_formatters ||= T.let([], T.nilable(T::Array[T::Class[T.anything]]))
      end

      #: (String name) -> OffensesFormatter
      def formatter_by_identifier(name)
        @formatter_by_identifier ||= T.let(nil, T.nilable(T::Hash[String, T.nilable(OffensesFormatter)]))
        @formatter_by_identifier ||= begin
          index = T.let({}, T::Hash[String, T.nilable(OffensesFormatter)])
          OffensesFormatter.all.each do |formatter|
            identifier = formatter.identifier
            raise DuplicateFormatterError, identifier if index.key?(identifier)

            index[identifier] = formatter
          end
          T.let(index, T.nilable(T::Hash[String, T.nilable(OffensesFormatter)]))
        end

        T.must(T.must(@formatter_by_identifier)[name])
      end
    end

    # @abstract
    #: (Array[Offense?] offenses) -> String
    def show_offenses(offenses) = raise NotImplementedError, "Abstract method called"

    # @abstract
    #: (OffenseCollection offense_collection, Set[String] for_files) -> String
    def show_stale_violations(offense_collection, for_files) = raise NotImplementedError, "Abstract method called"

    # @abstract
    #: -> String
    def identifier = raise NotImplementedError, "Abstract method called"

    # @abstract
    #: (Array[ReferenceOffense] strict_mode_violations) -> String
    def show_strict_mode_violations(strict_mode_violations) = raise NotImplementedError, "Abstract method called"
  end
end
