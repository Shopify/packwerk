# typed: true
# frozen_string_literal: true

module Packwerk
  # A general implementation of a graph data structure with the ability to check for - and list - cycles.
  class Graph
    extend T::Sig
    sig do
      params(
        # The edges of the graph; An edge being represented as an Array of two nodes.
        edges: T::Array[T::Array[T.any(String, Integer, NilClass)]]
      ).void
    end
    def initialize(edges)
      @edges = edges.uniq
      @cycles = Set.new
      process
    end

    def cycles
      @cycles.dup
    end

    def acyclic?
      @cycles.empty?
    end

    private

    def nodes
      @edges.flatten.uniq
    end

    def process
      # See https://en.wikipedia.org/wiki/Topological_sorting#Depth-first_search
      @processed ||= begin
        nodes.each { |node| visit(node) }
        true
      end
    end

    def visit(node, visited_nodes: Set.new, path: [])
      # Already visited, short circuit to avoid unnecessary processing
      return if visited_nodes.include?(node)

      # We've returned to a node that we've already visited, so we've found a cycle!
      if path.include?(node)
        # Filter out the part of the path that isn't a cycle. For example, with the following path:
        #
        #   a -> b -> c -> d -> b
        #
        # "a" isn't part of the cycle. The cycle should only appear once in the path, so we reject
        # everything from the beginning to the first instance of the current node.
        add_cycle(path.drop_while { |n| n != node })
        return
      end

      path << node
      neighbours(node).each do |neighbour|
        visit(neighbour, visited_nodes: visited_nodes, path: path)
      end
      path.pop
    ensure
      visited_nodes << node
    end

    def neighbours(node)
      @edges
        .lazy
        .select { |src, _dst| src == node }
        .map { |_src, dst| dst }
    end

    def add_cycle(cycle)
      # Ensure that the lexicographically smallest item is the first one labeled in a cycle
      min_node = cycle.min
      cycle.rotate! until cycle.first == min_node

      @cycles << cycle
    end
  end

  private_constant :Graph
end
