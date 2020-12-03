# typed: true
# frozen_string_literal: true

require "json"

module Packwerk
  class VisualizationGraph
    attr_reader :nodes, :edges

    GENERATED_FILE_DIR = File.join(__dir__, "tmp/packwerk")
    GENERATED_FILE_NAME = "visualization.html"
    HTML_TEMPLATE_PATH = File.join(__dir__, "generators/templates/dependencies_template.html")

    private_constant :GENERATED_FILE_DIR
    private_constant :GENERATED_FILE_NAME
    private_constant :HTML_TEMPLATE_PATH

    def initialize(edges: [])
      @edges = edges
      nodes_set = Set.new
      edges.each do |edge|
        nodes_set.add(edge[:from])
        nodes_set.add(edge[:to])
      end
      @nodes = nodes_set.to_a
      format_data
    end

    def generate_visualization_file(out_dir:, out_file_name: GENERATED_FILE_NAME, template_path: HTML_TEMPLATE_PATH)
      out_dir ||= GENERATED_FILE_DIR
      FileUtils.mkdir_p(out_dir)
      out_file_path = File.join(out_dir, out_file_name)
      template = File.read(template_path)
      filled_template = template
        .gsub("$nodesValues$", @formatted_nodes.to_json)
        .gsub("$edgesValues$", @formatted_edges.to_json)
      File.write(out_file_path, filled_template)
      puts("#{out_file_path} has been generated")
    end

    private

    def format_data
      @formatted_nodes = @nodes.map { |node| format_node(node) }
      @formatted_edges = @edges.map { |edge| format_edge(edge) }
    end

    def format_node(node)
      { 'id': node, 'label': node }
    end

    def format_edge(edge)
      { 'from': edge[:from], 'to': edge[:to], 'arrows': {
        'to': {
          'enabled': true,
          'type': "arrow",
        },
      }, 'color': edge[:arrow_color].empty? ? "blue" : edge[:arrow_color] }
    end
  end
end
