# typed: true
# frozen_string_literal: true

require "syntax_tree"

module Packwerk
  module Parsers
    class SyntaxTree
      include ParserInterface

      def call(io:, file_path: "<unknown>")
        ::SyntaxTree.parse(io.read)
      rescue ::SyntaxTree::Parser::ParseError => e
        result = ParseResult.new(file: file_path, message: "Syntax error: #{e}")
        raise Parsers::ParseError, result
      end
    end
  end
end
