# typed: ignore
# frozen_string_literal: true

require "test_helper"
require "parser_test_helper"

module Packwerk
  class NodeVisitorTest < Minitest::Test
    test "#visit visits the correct number of nodes" do
      node_processor = mock
      node_processor.expects(:call).times(3).returns(["an offense"])
      file_node_visitor = Packwerk::NodeVisitor.new(node_processor: node_processor)

      node = ParserTestHelper.parse("class Hello; world; end")
      result = []
      file_node_visitor.visit(node, ancestors: [], result: result)

      assert_equal 3, result.count
    end
  end
end
