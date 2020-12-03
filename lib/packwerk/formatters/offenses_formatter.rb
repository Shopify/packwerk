# typed: strict
# frozen_string_literal: true

require "benchmark"
require "sorbet-runtime"

require "packwerk/inflector"
require "packwerk/output_styles"

module Packwerk
  module Formatters
    class OffensesFormatter
      extend T::Sig

      sig do
        params(style: T.any(T.class_of(OutputStyles::Plain), T.class_of(OutputStyles::Coloured))).void
      end
      def initialize(style: OutputStyles::Plain)
        @style = style
      end

      sig { params(offenses: T::Array[T.nilable(Offense)]).returns(String) }
      def show_offenses(offenses)
        return "No offenses detected 🎉" if offenses.empty?

        <<~EOS
          #{offenses_list(offenses)}
          #{offenses_summary(offenses)}
        EOS
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
