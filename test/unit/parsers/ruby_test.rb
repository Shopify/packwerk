# typed: true
# frozen_string_literal: true

require "test_helper"
require "packwerk/parsers/ruby"

module Packwerk
  module Parsers
    class RubyTest < Minitest::Test
      test "#call returns node with valid file" do
        node = File.open(fixture_path("valid.rb"), "r") do |fixture|
          Ruby.new.call(io: fixture)
        end

        assert_kind_of(SyntaxTree::Node, node)
      end

      test "#call writes parse error to stdout" do
        file_path = fixture_path("invalid.rb")

        exception = assert_raises(Parsers::ParseError) do
          File.open(file_path, "r") do |fixture|
            Ruby.new.call(io: fixture, file_path: file_path)
          end
        end

        assert_equal(
          "Syntax error: syntax error, unexpected end-of-input, expecting `end' in #{file_path}",
          exception.message
        )
      end

      test "#call parses Ruby code containing invalid UTF-8 strings" do
        node = File.open(fixture_path("invalid_utf8_string.rb"), "r") do |fixture|
          Ruby.new.call(io: fixture)
        end

        assert_kind_of(SyntaxTree::Node, node)
      end

      private

      def fixture_path(name)
        ROOT.join("test/fixtures/formats/ruby", name).to_s
      end
    end
  end
end
