# typed: ignore
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class DependenciesVisualizerTest < ActiveSupport::TestCase
    setup do
      packages = [
        stub(name: "app/test/test1", dependencies: ["app/test/test2"]),
        stub(name: "app/test/test3", dependencies: ["app/test/test2"]),
      ]
      @package_set = Packwerk::PackageSet.new(packages)
    end

    test "returns visualization graph with correct data" do
      expected_edges = [
        { from: "app/test/test1", to: "app/test/test2", arrow_color: "blue" },
        { from: "app/test/test3", to: "app/test/test2", arrow_color: "blue" },
      ]

      graph = DependenciesVisualizer.new.visualization_graph(@package_set)

      assert_equal %w(app/test/test1 app/test/test2 app/test/test3), graph.nodes.sort
      assert_equal expected_edges, graph.edges
    end

    test "generates visualization file with correct data" do
      expected_template_value = "[{\"id\":\"app/test/test1\",\"label\":\"app/test/test1\"}," \
        "{\"id\":\"app/test/test2\",\"label\":\"app/test/test2\"},{\"id\":\"app/test/test3\",\"label\":" \
        "\"app/test/test3\"}] [{\"from\":\"app/test/test1\",\"to\":\"app/test/test2\",\"arrows\":{\"to\":" \
        "{\"enabled\":true,\"type\":\"arrow\"}},\"color\":\"blue\"},{\"from\":\"app/test/test3\",\"to\":\"" \
        "app/test/test2\",\"arrows\":{\"to\":{\"enabled\":true,\"type\":\"arrow\"}},\"color\":\"blue\"}]"

      Packwerk::PackageSet.expects(:load_all_from).returns(@package_set)
      FileUtils.stubs(:mkdir_p).returns(true)
      File.stubs(:read).returns("$nodesValues$ $edgesValues$")

      File.expects(:write).with(anything, expected_template_value).once

      DependenciesVisualizer.new.visualize({})
    end
  end
end
