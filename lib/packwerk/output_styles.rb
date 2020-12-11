# typed: strict
# frozen_string_literal: true

module Packwerk
  module OutputStyles
    Any = T.type_alias { T.any(T.class_of(Plain), T.class_of(Coloured)) }

    class Plain
      class << self
        extend T::Sig

        sig { returns(String) }
        def reset
          ""
        end

        sig { returns(String) }
        def filename
          ""
        end

        sig { returns(String) }
        def error
          ""
        end
      end
    end

    # See https://en.wikipedia.org/wiki/ANSI_escape_code#3/4_bit for ANSI escape colour codes
    class Coloured
      class << self
        extend T::Sig

        sig { returns(String) }
        def reset
          "\033[m"
        end

        sig { returns(String) }
        def filename
          # 36 is foreground cyan
          "\033[36m"
        end

        sig { returns(String) }
        def error
          # 31 is foreground red
          "\033[31m"
        end
      end
    end
  end
end
