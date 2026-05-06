# typed: strict
# frozen_string_literal: true

module Packwerk
  module Validator
    class Result
      #: bool
      attr_reader :ok

      #: String?
      attr_reader :error_value

      #: (ok: bool, ?error_value: String?) -> void
      def initialize(ok:, error_value: nil)
        @ok = ok
        @error_value = error_value
      end

      #: -> bool
      def ok?
        ok
      end
    end
  end
end
