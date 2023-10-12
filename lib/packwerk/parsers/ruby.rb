# typed: strict
# frozen_string_literal: true

require "parser"
require "parser/current"

module Packwerk
  module Parsers
    class Ruby
      extend T::Sig

      include Packwerk::FileParser

      RUBY_REGEX = %r{
        # Although not important for regex, these are ordered from most likely to match to least likely.
        \.(rb|rake|builder|gemspec|ru)\Z
        |
        (Gemfile|Rakefile)\Z
      }x
      private_constant :RUBY_REGEX

      class RaiseExceptionsParser < Parser::CurrentRuby
        extend T::Sig

        sig { params(builder: T.untyped).void }
        def initialize(builder)
          super(builder)
          super.diagnostics.all_errors_are_fatal = true
        end
      end

      class TolerateInvalidUtf8Builder < Parser::Builders::Default
        extend T::Sig

        sig { params(token: T.untyped).returns(T.untyped) }
        def string_value(token)
          value(token)
        end
      end

      sig { params(parser_class: T.untyped).void }
      def initialize(parser_class: RaiseExceptionsParser)
        @builder = T.let(TolerateInvalidUtf8Builder.new, Object)
        @parser_class = T.let(parser_class, T.class_of(RaiseExceptionsParser))
      end

      sig { override.params(io: T.any(IO, StringIO), file_path: String).returns(T.nilable(Parser::AST::Node)) }
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

      sig { override.params(path: String).returns(T::Boolean) }
      def match?(path:)
        RUBY_REGEX.match?(path)
      end
    end
  end
end
