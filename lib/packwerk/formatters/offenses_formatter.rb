# typed: strict
# frozen_string_literal: true

module Packwerk
  module Formatters
    class OffensesFormatter
      include Packwerk::OffensesFormatter

      extend T::Sig

      sig { params(style: OutputStyle).void }
      def initialize(style: OutputStyles::Plain.new)
        @style = style
      end

      sig { override.params(offenses: T::Array[T.nilable(Offense)]).returns(String) }
      def show_offenses(offenses)
        return "No offenses detected" if offenses.empty?

        <<~EOS
          #{offenses_list(offenses)}
          #{offenses_summary(offenses)}
        EOS
      end

      sig { override.params(offense_collection: Packwerk::OffenseCollection).returns(String) }
      def show_stale_violations(offense_collection)
        if offense_collection.stale_violations?
          "There were stale violations found, please run `packwerk update-deprecations`"
        else
          "No stale violations detected"
        end
      end

      sig { override.params(offense_collection: Packwerk::OffenseCollection).returns(String) }
      def show_stale_zeitwerk_violations(offense_collection)
        if offense_collection.stale_zeitwerk_violations?
          "There were stale Zeitwerk violations found, please run `packwerk update-zeitwerk-violations`"
        else
          "No stale violations detected"
        end
      end

      private

      sig { params(offenses: T::Array[T.nilable(Offense)]).returns(String) }
      def offenses_list(offenses)
        offenses
          .compact
          .map { |offense| offense.to_s(@style) }
          .join("\n")
      end

      sig { params(offenses: T::Array[T.nilable(Offense)]).returns(String) }
      def offenses_summary(offenses)
        offenses_string = Inflector.default.pluralize("offense", offenses.length)
        "#{offenses.length} #{offenses_string} detected"
      end
    end
  end
end
