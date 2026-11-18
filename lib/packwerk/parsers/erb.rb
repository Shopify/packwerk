# typed: strict
# frozen_string_literal: true

require "ast/node"
require "herb"
require "parser/source/buffer"

module Packwerk
  module Parsers
    class Erb
      include ParserInterface

      #: (?ruby_parser: Ruby) -> void
      def initialize(ruby_parser: Ruby.new)
        @ruby_parser = ruby_parser
      end

      # @override
      #: (io: (IO | StringIO), ?file_path: String) -> untyped
      def call(io:, file_path: "<unknown>")
        buffer = Parser::Source::Buffer.new(file_path)
        buffer.source = io.read
        parse_buffer(buffer, file_path: file_path)
      end

      #: (Parser::Source::Buffer buffer, file_path: String) -> AST::Node?
      def parse_buffer(buffer, file_path:)
        # `preserve_positions` blanks out everything that isn't Ruby, so line and column numbers
        # match the template. `semicolons` ends each ERB tag's code, so two tags on one line
        # stay separate statements.
        ruby_source = Herb.extract_ruby(buffer.source, semicolons: true, preserve_positions: true)

        @ruby_parser.call(
          io: StringIO.new(ruby_source),
          file_path: file_path,
        )
      rescue EncodingError => e
        result = ParseResult.new(file: file_path, message: e.message)
        raise Parsers::ParseError, result
      end
    end
  end
end
