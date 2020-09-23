# typed: true
# frozen_string_literal: true

module Packwerk
  module OutputStyles
    class Plain
      class << self
        def reset
          ""
        end

        def filename
          ""
        end

        def error
          ""
        end
      end
    end

    # See https://en.wikipedia.org/wiki/ANSI_escape_code#3/4_bit for ANSI escape colour codes
    class Coloured
      class << self
        def reset
          "\033[m"
        end

        def filename
          # 36 is foreground cyan
          "\033[36m"
        end

        def error
          # 31 is foreground red
          "\033[31m"
        end
      end
    end
  end
end
