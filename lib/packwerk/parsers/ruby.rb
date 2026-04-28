# typed: strict
# frozen_string_literal: true

require "parser"
require "prism"

module Packwerk
  module Parsers
    class Ruby
      extend T::Sig

      include ParserInterface

      class RaiseExceptionsParser < Prism::Translation::Parser
        extend T::Sig

        #: (untyped builder) -> void
        def initialize(builder)
          super(builder)
          super.diagnostics.all_errors_are_fatal = true
        end

        private

        #: (Prism::ParseError error) -> bool
        def valid_error?(error)
          error.type != :invalid_yield
        end
      end

      class TolerateInvalidUtf8Builder < Prism::Translation::Parser::Builder
        extend T::Sig

        #: (untyped token) -> untyped
        def string_value(token)
          value(token)
        end
      end

      #: (?parser_class: untyped) -> void
      def initialize(parser_class: RaiseExceptionsParser)
        @builder = TolerateInvalidUtf8Builder.new #: Object
        @parser_class = parser_class #: singleton(RaiseExceptionsParser)
      end

      # @override
      #: (io: (IO | StringIO), ?file_path: String) -> Parser::AST::Node?
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
