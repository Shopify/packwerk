# typed: strict
# frozen_string_literal: true

module Packwerk
  module OutputStyles
    class Plain
      include OutputStyle

      # @override
      #: -> String
      def reset
        ""
      end

      # @override
      #: -> String
      def filename
        ""
      end

      # @override
      #: -> String
      def error
        ""
      end
    end
  end
end
