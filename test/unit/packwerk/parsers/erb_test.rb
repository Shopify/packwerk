# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  module Parsers
    class ErbTest < Minitest::Test
      test "#extract_ruby_source returns Ruby source from a valid ERB file" do
        ruby_source = Erb.new.extract_ruby_source(file_path: fixture_path("valid.erb"))

        assert_kind_of(String, ruby_source)
        refute_empty(ruby_source)
      end

      test "#extract_ruby_source preserves embedded constant references" do
        ruby_source = Erb.new.extract_ruby_source(file_path: fixture_path("valid.erb"))

        # MyNamespace::MY_CONSTANT appears in valid.erb -- the extracted Ruby should
        # carry it through verbatim so Rubydex can parse it as a constant reference.
        assert_includes(ruby_source, "MyNamespace::MY_CONSTANT")
      end

      test "#extract_ruby_source preserves original line numbers" do
        ruby_source = Erb.new.extract_ruby_source(file_path: fixture_path("valid.erb"))
        refute_nil(ruby_source, "expected extract_ruby_source to return a String")

        # MyNamespace::MY_CONSTANT is on line 13 of the ERB source. Herb preserves
        # original line numbers (it pads with whitespace), so it should still be on line 13.
        line_with_constant = ruby_source.to_s.lines.index { |l| l.include?("MyNamespace::MY_CONSTANT") }
        refute_nil(line_with_constant, "expected MyNamespace::MY_CONSTANT in extracted Ruby")
        assert_equal(12, line_with_constant, "expected line 13 (0-based: 12) in extracted Ruby")
      end

      test "#extract_ruby_source handles ERB blocks that span tags" do
        # invalid.erb has `<% if condition %>...<% end %>` - blocks spanning tags
        ruby_source = Erb.new.extract_ruby_source(file_path: fixture_path("invalid.erb"))

        assert_kind_of(String, ruby_source)
      end

      private

      def fixture_path(name)
        ROOT.join("test/fixtures/formats/erb", name).to_s
      end
    end
  end
end
