# typed: strict
# frozen_string_literal: true

module Packwerk
  module Parsers
    # @requires_ancestor: Kernel
    # @interface
    module ParserInterface
      # @abstract
      #: (io: (IO | StringIO), file_path: String) -> untyped
      def call(io:, file_path:) = raise NotImplementedError, "Abstract method called"
    end
  end
end
