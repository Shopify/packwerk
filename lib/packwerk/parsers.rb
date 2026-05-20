# typed: strict
# frozen_string_literal: true

module Packwerk
  module Parsers
    autoload :Erb, "packwerk/parsers/erb"

    class ParseResult < Offense; end

    class ParseError < StandardError
      #: ParseResult
      attr_reader(:result)

      #: (ParseResult result) -> void
      def initialize(result)
        super(result.message)
        @result = result
      end
    end
  end
end
