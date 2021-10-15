# typed: ignore
# frozen_string_literal: true

require "test_helper"
require "ast"

# To Do remove
require "ripper"

module Packwerk
  module Parsers
    class RipperTest < Minitest::Test
      extend AST::Sexp
      [
        ["", [:program, [[:void_stmt]]], nil],
        ["1", [:program, [[:@int, "1", [1, 0]]]], s(:int, 1)],
        [
          "a = 1",
          [:program, [[:assign, [:var_field, [:@ident, "a", [1, 0]]], [:@int, "1", [1, 4]]]]],
          s(:lvasgn, :a, s(:int, 1))
        ],
        [
          "A = 1",
          [:program, [[:assign, [:var_field, [:@const, "A", [1, 0]]], [:@int, "1", [1, 4]]]]],
          s(:casgn, nil, :A, s(:int, 1))
        ],
        [
          "1; 2",
          [:program, [[:@int, "1", [1, 0]], [:@int, "2", [1, 3]]]],
          s(:begin, s(:int, 1), s(:int, 2))
        ],
        [
          "module Sales; end",
          [:program, [[:module, [:const_ref, [:@const, "Sales", [1, 7]]], [:bodystmt, [[:void_stmt]], nil, nil, nil]]]],
          s(:module, s(:const, nil, :Sales), nil)
        ]
      ].each_with_index do |(code, sexp, ast), index|
        test "#transform transforms sexp node #{index} into ::AST::Node" do
          assert_equal ast, Ripper.new.transform(sexp), "sexp parsed from:\n#{code}\n"
        end
      end

      test "#call returns parser-gem compatible AST" do
        [
          # "",
          # "1",
          # "a = 1",
          # "A = 1",
          # "1; 2",
          # "module Sales; end",
          "module Sales; 1; end",
        ].each do |code|
          assert_equal(
            Ruby.new.call(io: StringIO.new(code)),
            ::Ripper.sexp(code)
          )
        end
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

      # private

      # def fixture_path(name)
      #   ROOT.join("test/fixtures/formats/ruby", name).to_s
      # end
    end
  end
end
