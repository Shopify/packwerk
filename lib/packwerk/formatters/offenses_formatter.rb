# typed: strict
# frozen_string_literal: true

module Packwerk
  module Formatters
    class OffensesFormatter
      include Packwerk::OffensesFormatter

      IDENTIFIER = T.let("default", String)

      extend T::Sig

      sig { override.params(offenses: T::Array[T.nilable(Offense)]).returns(String) }
      def show_offenses(offenses)
        return "No offenses detected" if offenses.empty?

        <<~EOS
          #{offenses_list(offenses)}
          #{offenses_summary(offenses)}
        EOS
      end

      sig { override.params(offense_collection: Packwerk::OffenseCollection, fileset: T::Set[String]).returns(String) }
      def show_stale_violations(offense_collection, fileset)
        if offense_collection.stale_violations?(fileset)
          "There were stale violations found, please run `packwerk update-todo`"
        else
          "No stale violations detected"
        end
      end

      sig { override.returns(String) }
      def identifier
        IDENTIFIER
      end

      private

      sig { returns(OutputStyle) }
      def style
        @style ||= T.let(Packwerk::OutputStyles::Coloured.new, T.nilable(Packwerk::OutputStyles::Coloured))
      end

      sig { params(offenses: T::Array[T.nilable(Offense)]).returns(String) }
      def offenses_list(offenses)
        offenses
          .compact
          .map { |offense| offense.to_s(style) }
          .join("\n")
      end

      sig { params(offenses: T::Array[T.nilable(Offense)]).returns(String) }
      def offenses_summary(offenses)
        offenses_string = "offense".pluralize(offenses.length)
        "#{offenses.length} #{offenses_string} detected"
      end
    end
  end
end
