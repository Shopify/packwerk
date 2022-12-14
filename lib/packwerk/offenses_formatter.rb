# typed: strict
# frozen_string_literal: true

module Packwerk
  module OffensesFormatter
    extend T::Sig
    extend T::Helpers

    abstract!

    class DuplicateFormatterError < StandardError
      extend T::Sig

      sig { params(identifier: String).void }
      def initialize(identifier)
        super("Cannot have multiple identifiers with the same key (`#{identifier}`)")
      end
    end

    class << self
      extend T::Sig

      sig { params(base: Class).void }
      def included(base)
        @offenses_formatters ||= T.let(@offenses_formatters, T.nilable(T::Array[Class]))
        @offenses_formatters ||= []
        @offenses_formatters << base
      end

      sig { returns(T::Array[OffensesFormatter]) }
      def all
        T.unsafe(@offenses_formatters).map(&:new)
      end

      sig { params(identifier: String).returns(OffensesFormatter) }
      def find(identifier)
        formatter_by_identifier(identifier)
      end

      private

      sig { params(name: String).returns(OffensesFormatter) }
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

    sig { abstract.params(offenses: T::Array[T.nilable(Offense)]).returns(String) }
    def show_offenses(offenses)
    end

    sig { abstract.params(offense_collection: OffenseCollection, for_files: T::Set[String]).returns(String) }
    def show_stale_violations(offense_collection, for_files)
    end

    sig { abstract.returns(String) }
    def identifier
    end

    sig { abstract.params(strict_mode_violations: T::Array[ReferenceOffense]).returns(String) }
    def show_strict_mode_violations(strict_mode_violations)
    end
  end
end
