# typed: ignore
# frozen_string_literal: true

require "test_helper"
require "packwerk/visualization_graph"

module Packwerk
  class VisualizationGraphTest < ActiveSupport::TestCase
    setup do
      @edges = [
        { from: "app/test/test1", to: "app/test/test2", arrow_color: "blue" },
        { from: "app/test/test3", to: "app/test/test2", arrow_color: "blue" },
      ]
    end

    test "calculates nodes correctly" do
      assert_equal %w(app/test/test1 app/test/test2 app/test/test3), VisualizationGraph.new(edges: @edges).nodes.sort
    end

    test "calculates edges correctly" do
      expected_edges = [
        { from: "app/test/test1", to: "app/test/test2", arrow_color: "blue" },
        { from: "app/test/test3", to: "app/test/test2", arrow_color: "blue" },
      ]

      assert_equal expected_edges, VisualizationGraph.new(edges: @edges).edges
    end

    test "generates visualization file with provided path" do
      FileUtils.stubs(:mkdir_p).returns(true)
      File.stubs(:read).returns("$nodesValues$ $edgesValues$")
      out_dir = "/test/"
      out_file_name = "file.html"

      File.expects(:write).with(File.join(out_dir, out_file_name), anything).once

      VisualizationGraph.new(edges: @edges).generate_visualization_file(out_dir: out_dir, out_file_name: out_file_name)
    end

    test "generates correct visualization file" do
      edges = [{ from: "app/test/test1", to: "app/test/test1", arrow_color: "blue" }]
      expected_template_value = "[{\"id\":\"app/test/test1\",\"label\":\"app/test/test1\"}] " \
        "[{\"from\":\"app/test/test1\",\"to\":\"app/test/test1\",\"arrows\":{\"to\":" \
        "{\"enabled\":true,\"type\":\"arrow\"}},\"color\":\"blue\"}]"
      FileUtils.stubs(:mkdir_p).returns(true)
      File.stubs(:read).returns("$nodesValues$ $edgesValues$")

      File.expects(:write).with(anything, expected_template_value).once

      VisualizationGraph.new(edges: edges).generate_visualization_file(out_dir: nil)
    end
  end
end
