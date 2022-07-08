# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  module Parsers
    class RubyTest < Minitest::Test
      test "#call returns node with valid file" do
        node = File.open(fixture_path("valid.rb"), "r") do |fixture|
          Ruby.new.call(io: fixture)
        end

        assert_kind_of(::AST::Node, node)
      end

      test "#call writes parse error to stdout" do
        error_message = "stub error"
        err = Parser::SyntaxError.new(stub(message: error_message))
        parser = stub
        parser.stubs(:parse).raises(err)

        parser_class_stub = stub(new: parser)

        parser = Ruby.new(parser_class: parser_class_stub)
        file_path = fixture_path("invalid.rb")

        exc = assert_raises(Parsers::ParseError) do
          File.open(file_path, "r") do |fixture|
            parser.call(io: fixture, file_path: file_path)
          end
        end

        assert_equal("Syntax error: stub error", exc.result.message)
        assert_equal(file_path, exc.result.file)
      end

      test "#call writes encoding error to stdout" do
        error_message = "stub error"
        err = EncodingError.new(error_message)
        parser = stub
        parser.stubs(:parse).raises(err)

        parser_class_stub = stub(new: parser)

        parser = Ruby.new(parser_class: parser_class_stub)
        file_path = fixture_path("invalid.rb")

        exc = assert_raises(Parsers::ParseError) do
          File.open(file_path, "r") do |fixture|
            parser.call(io: fixture, file_path: file_path)
          end
        end

        assert_equal("stub error", exc.result.message)
        assert_equal(file_path, exc.result.file)
      end

      test "#call parses Ruby code containing invalid UTF-8 strings" do
        node = File.open(fixture_path("invalid_utf8_string.rb"), "r") do |fixture|
          Ruby.new.call(io: fixture)
        end

        assert_kind_of(::AST::Node, node)
      end

      private

      def fixture_path(name)
        ROOT.join("test/fixtures/formats/ruby", name).to_s
      end
    end
  end
end
