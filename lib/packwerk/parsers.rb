# typed: true
# frozen_string_literal: true

module Packwerk
  module Parsers
    autoload :Erb, "packwerk/parsers/erb"
    autoload :Factory, "packwerk/parsers/factory"
    autoload :ParserInterface, "packwerk/parsers/parser_interface"
    autoload :Ruby, "packwerk/parsers/ruby"
    autoload :SyntaxTree, "packwerk/parsers/syntax_tree"

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
