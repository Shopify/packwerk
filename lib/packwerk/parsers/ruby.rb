# typed: true
# frozen_string_literal: true

module Packwerk
  module Parsers
    class Ruby
      def initialize(parser: RubyVM::AbstractSyntaxTree)
        @parser = parser
      end

      def call(io:, file_path: "<unknown>")
        string = io.read
        without_warnings { @parser.parse(string) }
      rescue EncodingError => e
        result = ParseResult.new(file: file_path, message: e.message)
        raise Parsers::ParseError, result
      rescue SyntaxError => e
        result = ParseResult.new(file: file_path, message: "Syntax error: #{e}")
        raise Parsers::ParseError, result
      end

      private

      def without_warnings
        previous_verbosity = $VERBOSE
        $VERBOSE = false

        begin
          yield
        ensure
          $VERBOSE = previous_verbosity
        end
      end
    end
  end
end
