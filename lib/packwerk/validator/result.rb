# typed: strict
# frozen_string_literal: true

module Packwerk
  module Validator
    class Result < T::Struct

      const :ok, T::Boolean
      const :error_value, T.nilable(String)

      #: -> bool
      def ok?
        ok
      end
    end
  end
end
