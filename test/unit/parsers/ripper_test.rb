# typed: ignore
# frozen_string_literal: true

require "test_helper"

require "ripper"
require "ast"

module Packwerk
  module Parsers
    class RipperTest < Minitest::Test
      include AST::Sexp

      test "#call returns the same AST as the parser gem" do
        [
          "",
          "1",
          "a",
          "a = 1",
          "A",
          "A = 1",
          "1; 2",
          "module Sales; end",
          "module Sales; 1; end",
          "module Sales; class Order; end; end",
          "module Sales::Order::Something; end",
          "Sales::HELLO = 1",
          "class Order < ActiveRecord::Base; end",
          "::Sales::HELLO",
          "# comment",
          "1 + 2",
          "a = 1 + 1",
          "a.b",
          "a do |b|; c; end",
          "a do |b, c|; d; end",
          "a(1)",
          "a(1) { |b| c }",
          "a do b end",
          "setup do self.a; b end",
          "begin 1 end",
          "setup do self.class::HEADERS end",
        ].each do |code|
          assert_equal(
            Ruby.new.call(io: StringIO.new(code)),
            begin
              parse(code)
            rescue NotImplementedError => e
              "Not Implemented: #{e.message}"
            end
          )
        end
      end

      test "#call omits strings" do
        assert_equal(s(:casgn, nil, :A, nil), parse("A = \"Hello World\""))
      end

      test "#call sets location for constants" do
        # location.name is Parser::AST::Node interface
        location = parse("A").location.name
        assert_equal 1, location.line
        assert_equal 0, location.column

        location = parse("A = 1").location.name
        assert_equal 1, location.line
        assert_equal 0, location.column
      end

      # test "#call returns node with valid file" do
      #   node = File.open(fixture_path("valid.rb"), "r") do |fixture|
      #     Ruby.new.call(io: fixture)
      #   end

      #   assert_kind_of(::AST::Node, node)
      # end

      # test "#call writes parse error to stdout" do
      #   error_message = "stub error"
      #   err = Parser::SyntaxError.new(stub(message: error_message))
      #   parser = stub
      #   parser.stubs(:parse).raises(err)

      #   parser_class_stub = stub(new: parser)

      #   parser = Ruby.new(parser_class: parser_class_stub)
      #   file_path = fixture_path("invalid.rb")

      #   exc = assert_raises(Parsers::ParseError) do
      #     File.open(file_path, "r") do |fixture|
      #       parser.call(io: fixture, file_path: file_path)
      #     end
      #   end

      #   assert_equal("Syntax error: stub error", exc.result.message)
      #   assert_equal(file_path, exc.result.file)
      # end

      # test "#call writes encoding error to stdout" do
      #   error_message = "stub error"
      #   err = EncodingError.new(error_message)
      #   parser = stub
      #   parser.stubs(:parse).raises(err)

      #   parser_class_stub = stub(new: parser)

      #   parser = Ruby.new(parser_class: parser_class_stub)
      #   file_path = fixture_path("invalid.rb")

      #   exc = assert_raises(Parsers::ParseError) do
      #     File.open(file_path, "r") do |fixture|
      #       parser.call(io: fixture, file_path: file_path)
      #     end
      #   end

      #   assert_equal("stub error", exc.result.message)
      #   assert_equal(file_path, exc.result.file)
      # end

      # test "#call parses Ruby code containing invalid UTF-8 strings" do
      #   node = File.open(fixture_path("invalid_utf8_string.rb"), "r") do |fixture|
      #     Ruby.new.call(io: fixture)
      #   end

      #   assert_kind_of(::AST::Node, node)
      # end

      private

      def parse(source)
        Packwerk::Parsers::Ripper.new.call(io: StringIO.new(source))
      end

      # def fixture_path(name)
      #   ROOT.join("test/fixtures/formats/ruby", name).to_s
      # end
    end
  end
end
