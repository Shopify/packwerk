# typed: ignore
# frozen_string_literal: true

require "test_helper"

module Packwerk
  module Parsers
    class RubyTest < Minitest::Test
      test "#call returns node with valid file" do
        node = File.open(fixture_path("valid.rb"), "r") do |fixture|
          Ruby.new.call(io: fixture)
        end

        assert_kind_of(::RubyVM::AbstractSyntaxTree::Node, node)
      end

      test "#call writes parse error to stdout" do
        error_message = "stub error"
        err = SyntaxError.new(error_message)
        parser_stub = stub
        parser_stub.stubs(:parse).raises(err)

        parser = Ruby.new(parser: parser_stub)
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
        parser_stub = stub
        parser_stub.stubs(:parse).raises(err)

        parser = Ruby.new(parser: parser_stub)
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

        assert_kind_of(::RubyVM::AbstractSyntaxTree::Node, node)
      end

      test "#call doesn’t emit warnings about parsed code" do
        parser = Ruby.new
        source = StringIO.new("UselessConstant")

        with_warnings do
          assert_silent { parser.call(io: source) }
        end
      end

      private

      def fixture_path(name)
        ROOT.join("test/fixtures/formats/ruby", name).to_s
      end

      def with_warnings
        previous_verbosity = $VERBOSE
        $VERBOSE = true

        begin
          yield
        ensure
          $VERBOSE = previous_verbosity
        end
      end
    end
  end
end
