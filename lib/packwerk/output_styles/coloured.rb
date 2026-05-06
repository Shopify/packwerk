# typed: strict
# frozen_string_literal: true

module Packwerk
  module OutputStyles
    # See https://en.wikipedia.org/wiki/ANSI_escape_code#3/4_bit for ANSI escape colour codes
    class Coloured
      include OutputStyle

      # @override
      #: -> String
      def reset
        "\033[m"
      end

      # @override
      #: -> String
      def filename
        # 36 is foreground cyan
        "\033[36m"
      end

      # @override
      #: -> String
      def error
        # 31 is foreground red
        "\033[31m"
      end
    end
  end
end
