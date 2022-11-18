# typed: true
# frozen_string_literal: true

require "parser"
require "parser/current"

module Packwerk
  module Parsers
    class Ruby
      include Packwerk::Parser

      RUBY_REGEX = %r{
        # Although not important for regex, these are ordered from most likely to match to least likely.
        \.(rb|rake|builder|gemspec|ru)\Z
        |
        (Gemfile|Rakefile)\Z
      }x
      private_constant :RUBY_REGEX

      class RaiseExceptionsParser < ::Parser::CurrentRuby
        def initialize(builder)
          super(builder)
          super.diagnostics.all_errors_are_fatal = true
        end
      end

      class TolerateInvalidUtf8Builder < ::Parser::Builders::Default
        def string_value(token)
          value(token)
        end
      end

      def initialize(parser_class: RaiseExceptionsParser)
        @builder = TolerateInvalidUtf8Builder.new
        @parser_class = parser_class
      end

      def call(io:, file_path: "<unknown>")
        buffer = ::Parser::Source::Buffer.new(file_path)
        buffer.source = io.read
        parser = @parser_class.new(@builder)
        parser.parse(buffer)
      rescue EncodingError => e
        result = ParseResult.new(file: file_path, message: e.message)
        raise Parsers::ParseError, result
      rescue ::Parser::SyntaxError => e
        result = ParseResult.new(file: file_path, message: "Syntax error: #{e}")
        raise Parsers::ParseError, result
      end

      def match?(path:)
        RUBY_REGEX.match?(path)
      end
    end
  end
end
