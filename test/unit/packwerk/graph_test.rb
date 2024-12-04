# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class GraphTest < Minitest::Test
    test "#acyclic? returns true for a directed acyclic graph" do
      graph = Graph.new({ 1 => [2, 3], 2 => [4], 3 => [4] })

      assert_predicate graph, :acyclic?
    end

    test "#acyclic? returns false for a cyclic graph" do
      graph = Graph.new({ 1 => [2], 2 => [3], 3 => [1] })

      refute_predicate graph, :acyclic?
    end

    test "#cycles returns all cycles in a graph" do
      #
      # 1 -> 2 <-> 3
      #  \
      #   \
      #    -> 4 --> 5
      #       ^      \
      #       |      |
      #       +- 6 <-
      #
      graph = Graph.new({ 1 => [2, 4], 2 => [3], 3 => [2], 4 => [5], 5 => [6], 6 => [4] })

      assert_equal [[2, 3], [4, 5, 6]], graph.cycles.sort
    end

    test "#cycles returns overlapping cycles in a graph" do
      graph = Graph.new({ 1 => [2, 4], 2 => [3], 3 => [1], 4 => [3] })

      assert_equal [[1, 2, 3, 4]], graph.cycles.sort
    end

    test "#cycles returns cycles in a graph with disjoint subgraphs" do
      graph = Graph.new({
        1 => [2], 2 => [3], 3 => [1],
        4 => [5, 6], 5 => [7], 6 => [7],
        8 => [9, 10, 11], 9 => [8], 10 => [11],
      })

      assert_equal [[1, 2, 3], [8, 9]], graph.cycles.sort
    end
  end
end
