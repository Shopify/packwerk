# typed: true
# frozen_string_literal: true

require "ast/node"
require "better_html"
require "better_html/parser"
require "parser/source/buffer"

module Packwerk
  module Parsers
    class Erb
      def initialize(parser_class: BetterHtml::Parser, ruby_parser: Ruby.new)
        @parser_class = parser_class
        @ruby_parser = ruby_parser
      end

      def call(io:, file_path: "<unknown>")
        buffer = Parser::Source::Buffer.new(file_path)
        buffer.source = io.read
        parse_buffer(buffer, file_path: file_path)
      end

      def parse_buffer(buffer, file_path:)
        parser = @parser_class.new(buffer, template_language: :html)
        to_ruby_ast(parser.ast, file_path)
      rescue EncodingError => e
        result = ParseResult.new(file: file_path, message: e.message)
        raise Parsers::ParseError, result
      rescue Parser::SyntaxError => e
        result = ParseResult.new(file: file_path, message: "Syntax error: #{e}")
        raise Parsers::ParseError, result
      end

      private

      def to_ruby_ast(erb_ast, file_path)
        # Note that we're not using the source location (line/column) at the moment, but if we did
        # care about that, we'd need to tweak this to insert empty lines and spaces so that things
        # line up with the ERB file
        code_pieces = code_nodes(erb_ast).map do |node|
          node.children.first
        end

        @ruby_parser.call(
          io: StringIO.new(code_pieces.join("\n")),
          file_path: file_path,
        )
      end

      def code_nodes(node)
        return enum_for(:code_nodes, node) unless block_given?
        return unless node.is_a?(::AST::Node)

        yield node if node.type == :code

        # Skip descending into an ERB comment node, which may contain code nodes
        if node.type == :erb
          first_child = node.children.first
          return if first_child&.type == :indicator && first_child&.children&.first == "#"
        end

        node.children.each do |child|
          code_nodes(child) { |n| yield n }
        end
      end
    end
  end
end
