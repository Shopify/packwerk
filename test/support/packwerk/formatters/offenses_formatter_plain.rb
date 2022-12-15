# typed: strict
# frozen_string_literal: true

module Packwerk
  module Formatters
    class OffensesFormatterPlain < DefaultOffensesFormatter
      include OffensesFormatter
      IDENTIFIER = T.let("plain", String)

      extend T::Sig

      sig { override.returns(String) }
      def identifier
        IDENTIFIER
      end

      private

      sig { returns(OutputStyle) }
      def style
        @style ||= T.let(Packwerk::OutputStyles::Plain.new, T.nilable(Packwerk::OutputStyle))
      end
    end
  end
end
