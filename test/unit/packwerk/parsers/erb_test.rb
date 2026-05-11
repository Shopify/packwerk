# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  module Parsers
    class ErbTest < Minitest::Test
      test "#call returns node with valid file" do
        node = File.open(fixture_path("valid.erb"), "r") do |fixture|
          Erb.new.call(io: fixture)
        end

        assert_kind_of(::AST::Node, node)
      end

      test "#call returns nil when the ERB contains no Ruby" do
        node = File.open(fixture_path("javascript_valid.erb"), "r") do |fixture|
          Erb.new.call(io: fixture)
        end

        assert_nil(node)
      end

      test "#call raises ParseError with the file path when the embedded Ruby has a syntax error" do
        file_path = fixture_path("invalid.erb")

        exc = assert_raises(Parsers::ParseError) do
          File.open(file_path, "r") do |fixture|
            Erb.new.call(io: fixture, file_path: file_path)
          end
        end

        assert_match(/Syntax error/, exc.result.message)
        assert_equal(file_path, exc.result.file)
      end

      test "#call wraps an EncodingError as a ParseError with the file path" do
        Herb.stubs(:extract_ruby).raises(EncodingError, "stub error")

        file_path = fixture_path("valid.erb")

        exc = assert_raises(Parsers::ParseError) do
          File.open(file_path, "r") do |fixture|
            Erb.new.call(io: fixture, file_path: file_path)
          end
        end

        assert_equal("stub error", exc.result.message)
        assert_equal(file_path, exc.result.file)
      end

      private

      def fixture_path(name)
        ROOT.join("test/fixtures/formats/erb", name).to_s
      end
    end
  end
end
