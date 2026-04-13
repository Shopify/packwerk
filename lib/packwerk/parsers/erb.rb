# typed: strict
# frozen_string_literal: true

require "ast/node"
require "better_html"
require "better_html/parser"
require "parser/source/buffer"

module Packwerk
  module Parsers
    class Erb
      extend T::Sig

      sig { params(parser_class: T.untyped).void }
      def initialize(parser_class: BetterHtml::Parser)
        @parser_class = T.let(parser_class, T.class_of(BetterHtml::Parser))
      end

      # Extract the Ruby source code embedded in an ERB file.
      # Used by RunContext to feed ERB-embedded Ruby into Rubydex via index_source.
      sig { params(file_path: String).returns(T.nilable(String)) }
      def extract_ruby_source(file_path:)
        source = File.read(file_path, encoding: Encoding::UTF_8)
        buffer = Parser::Source::Buffer.new(file_path)
        buffer.source = source
        parser = @parser_class.new(buffer, template_language: :html)
        code_pieces = T.must(code_nodes(parser.ast)).map do |node|
          T.cast(node, ::AST::Node).children.first
        end
        ruby_source = code_pieces.join("\n")
        ruby_source.empty? ? nil : ruby_source
      rescue EncodingError, Parser::SyntaxError
        nil
      end

      private

      sig do
        params(
          node: T.any(::AST::Node, String, NilClass),
          block: T.nilable(T.proc.params(arg0: ::AST::Node).void),
        ).returns(
          T.any(T::Enumerator[::AST::Node], T::Array[String], NilClass)
        )
      end
      def code_nodes(node, &block)
        return enum_for(:code_nodes, node) unless block
        return unless node.is_a?(::AST::Node)

        yield node if node.type == :code

        # Skip descending into an ERB comment node, which may contain code nodes
        if node.type == :erb
          first_child = node.children.first
          return if first_child&.type == :indicator && first_child&.children&.first == "#"
        end

        node.children.each do |child|
          code_nodes(child, &block)
        end
      end
    end
  end
end
