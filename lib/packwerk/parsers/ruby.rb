# typed: true
# frozen_string_literal: true

require "parser"
require "parser/current"

module Packwerk
  module Parsers
    class Ruby
      include ParserInterface

      class RaiseExceptionsParser < Parser::CurrentRuby
        def initialize(builder)
          super(builder)
          super.diagnostics.all_errors_are_fatal = true
        end
      end

      class TolerateInvalidUtf8Builder < Parser::Builders::Default
        def string_value(token)
          value(token)
        end
      end

      def initialize(parser_class: RaiseExceptionsParser)
        @builder = TolerateInvalidUtf8Builder.new
        @parser_class = parser_class
      end

      def call(io:, file_path: "<unknown>")
        buffer = Parser::Source::Buffer.new(file_path)
        buffer.source = io.read
        parser = @parser_class.new(@builder)
        parser.parse(buffer)
      rescue EncodingError => e
        result = ParseResult.new(file: file_path, message: e.message)
        raise Parsers::ParseError, result
      rescue Parser::SyntaxError => e
        result = ParseResult.new(file: file_path, message: "Syntax error: #{e}")
        raise Parsers::ParseError, result
      end
    end
  end
end
