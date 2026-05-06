# typed: strict
# frozen_string_literal: true

module Packwerk
  module Formatters
    class OffensesFormatterPlain < DefaultOffensesFormatter
      include OffensesFormatter
      IDENTIFIER = "plain" #: String

      # @override
      #: -> String
      def identifier
        IDENTIFIER
      end

      private

      #: -> OutputStyle
      def style
        @style ||= Packwerk::OutputStyles::Plain.new #: Packwerk::OutputStyle?
      end
    end
  end
end
