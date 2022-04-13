# typed: strict
# frozen_string_literal: true

module Packwerk
  module Parsers
    module ParserInterface
      extend T::Helpers
      extend T::Sig

      requires_ancestor { Kernel }

      interface!

      sig { abstract.params(io: File, file_path: String).returns(T.untyped) }
      def call(io:, file_path:)
      end
    end
  end
end
