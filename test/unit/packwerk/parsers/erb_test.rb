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

      test "#call returns nil for a file with no Ruby code" do
        node = File.open(fixture_path("javascript_valid.erb"), "r") do |fixture|
          Erb.new.call(io: fixture)
        end

        assert_nil(node)
      end

      test "#call keeps the line and column of constants from the template" do
        node = File.open(fixture_path("valid.erb"), "r") do |fixture|
          Erb.new.call(io: fixture)
        end

        constant = find_const(node, :MY_CONSTANT)

        refute_nil(constant)
        assert_equal(Node::Location.new(13, 26), NodeHelpers.location(constant))
      end

      test "#call parses several ERB tags on the same line as separate statements" do
        node = Erb.new.call(io: StringIO.new("<p><%= Foo %> and <%= Bar %></p>"))

        assert_equal(:begin, node.type)
        assert_equal([:Foo, :Bar], node.children.map { |child| child.children.last })
      end

      test "#call parses Ruby blocks that span several ERB tags" do
        source = <<~ERB
          <%= form_for(:user) do |f| %>
            <div><%= f.text_field Sales::Order %></div>
          <% end %>
        ERB

        node = Erb.new.call(io: StringIO.new(source))

        refute_nil(find_const(node, :Order))
      end

      test "#call ignores code in ERB comments" do
        node = Erb.new.call(io: StringIO.new("<%# Hidden::Constant %>\n<%= Shown %>"))

        assert_nil(find_const(node, :Hidden))
        refute_nil(find_const(node, :Shown))
      end

      test "#call raises a parse error for a Ruby syntax error" do
        file_path = fixture_path("invalid.erb")

        exc = assert_raises(Parsers::ParseError) do
          File.open(file_path, "r") do |fixture|
            Erb.new.call(io: fixture, file_path: file_path)
          end
        end

        assert_match(/\ASyntax error: /, exc.result.message)
        assert_equal(file_path, exc.result.file)
      end

      test "#call raises a parse error for an encoding error" do
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

      def find_const(node, name)
        return unless node.is_a?(::AST::Node)
        return node if node.type == :const && node.children.last == name

        node.children.each do |child|
          found = find_const(child, name)
          return found if found
        end

        nil
      end
    end
  end
end
