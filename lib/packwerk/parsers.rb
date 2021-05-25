# typed: true
# frozen_string_literal: true

module Packwerk
  module Parsers
    autoload :Erb, "packwerk/parsers/erb"
    autoload :Factory, "packwerk/parsers/factory"
    autoload :Ruby, "packwerk/parsers/ruby"

    class ParseResult < Offense; end

    class ParseError < StandardError
      attr_reader :result

      def initialize(result)
        super(result.message)
        @result = result
      end
    end
  end
end
