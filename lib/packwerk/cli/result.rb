# typed: strict
# frozen_string_literal: true

module Packwerk
  class Cli
    class Result < T::Struct
      const :message, String
      const :print_as_error, T::Boolean, default: false
      const :status, T::Boolean
    end
  end
end
