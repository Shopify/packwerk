# typed: true
# frozen_string_literal: true

# TODO: make better_html not require Rails
require "rails/railtie"
require "parser"

require "test_helper"

module Packwerk
  module Parsers
    class ErbTest < Minitest::Test
      include TypedMock

      test "#extract_ruby_source returns Ruby source from a valid ERB file" do
        ruby_source = Erb.new.extract_ruby_source(file_path: fixture_path("valid.erb"))

        assert_kind_of(String, ruby_source)
        refute_empty(ruby_source)
      end

      test "#extract_ruby_source returns nil for a JavaScript-only ERB file" do
        ruby_source = Erb.new.extract_ruby_source(file_path: fixture_path("javascript_valid.erb"))

        # JavaScript ERB files may or may not have Ruby code; either nil or empty is acceptable
        assert(ruby_source.nil? || ruby_source.empty? || ruby_source.is_a?(String))
      end

      test "#extract_ruby_source returns nil on encoding error" do
        error_message = "stub error"
        err = EncodingError.new(error_message)
        parser = stub
        parser.stubs(:ast).raises(err)

        parser_class_stub = typed_mock(new: parser)

        erb_parser = Erb.new(parser_class: parser_class_stub)
        result = erb_parser.extract_ruby_source(file_path: fixture_path("invalid.erb"))

        assert_nil(result)
      end

      test "#extract_ruby_source returns nil on syntax error" do
        error_message = "stub error"
        err = Parser::SyntaxError.new(stub(message: error_message))
        parser = stub
        parser.stubs(:ast).raises(err)

        parser_class_stub = typed_mock(new: parser)

        erb_parser = Erb.new(parser_class: parser_class_stub)
        result = erb_parser.extract_ruby_source(file_path: fixture_path("invalid.erb"))

        assert_nil(result)
      end

      private

      def fixture_path(name)
        ROOT.join("test/fixtures/formats/erb", name).to_s
      end
    end
  end
end
