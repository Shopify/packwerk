# typed: strict
# frozen_string_literal: true

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

      # `Herb.extract_ruby` returns the Ruby parts of the ERB source with whitespace padding
      # so character positions match the original file — that gives Packwerk's downstream
      # reference offenses accurate line/column info in ERB templates.
      #: (Parser::Source::Buffer buffer, file_path: String) -> AST::Node?
      def parse_buffer(buffer, file_path:)
        ruby_source = Herb.extract_ruby(buffer.source)
        @ruby_parser.call(io: StringIO.new(ruby_source), file_path: file_path)
      rescue EncodingError => e
        result = ParseResult.new(file: file_path, message: e.message)
        raise Parsers::ParseError, result
      end
    end
  end
end
