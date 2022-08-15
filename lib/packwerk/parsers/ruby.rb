# typed: true
# frozen_string_literal: true

require "syntax_tree"

module Packwerk
  module Parsers
    class Ruby
      include ParserInterface

      def initialize(parser_class: SyntaxTree)
        @parser_class = parser_class
      end

      def call(io:, file_path: "<unknown>")
        @parser_class.parse(io.read)
      rescue SyntaxTree::Parser::ParseError => e
        result = ParseResult.new(file: file_path, message: "Syntax error: #{e}")
        raise Parsers::ParseError, result
      end
    end
  end
end
