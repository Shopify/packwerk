# typed: strict
# frozen_string_literal: true

module Packwerk
  module Parsers
    module ParserInterface
      extend T::Helpers
      extend T::Sig

      requires_ancestor { Kernel }

      interface!

      # @abstract
      #: (io: (IO | StringIO), file_path: String) -> untyped
      def call(io:, file_path:) = raise NotImplementedError, "Abstract method called"
    end
  end
end
