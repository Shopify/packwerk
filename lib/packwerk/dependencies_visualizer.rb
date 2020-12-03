# typed: true
# frozen_string_literal: true

require "optparse"

require "packwerk/visualization_graph"

module Packwerk
  class DependenciesVisualizer
    DEPRECATED_REFERENCES_FILE_NAME = "deprecated_references.yml"

    def visualize(args)
      options = options(args)
      package_set = Packwerk::PackageSet.load_all_from(".", package_pathspec: options[:package])
      visualization_graph = DependenciesVisualizer.new.visualization_graph(package_set)
      visualization_graph.generate_visualization_file(out_dir: options[:out_dir])
      true
    end

    def visualization_graph(package_set)
      Packwerk::VisualizationGraph.new(edges: edges(package_set))
    end

    private

    def edges(package_set)
      edges = []
      package_set.each do |package|
        package.dependencies.each do |dependency|
          edges.push({ from: package.name, to: dependency, arrow_color: "blue" })
        end
        deprecated_references(package.name).each do |reference|
          edges.push({ from: package.name, to: reference, arrow_color: "red" })
        end
      end
      edges
    end

    def deprecated_references(package_name)
      path = File.join(package_name, DEPRECATED_REFERENCES_FILE_NAME)
      File.exist?(path) ? YAML.load_file(path).keys : []
    end

    def options(args)
      options = {
        out_dir: nil,
        package: nil,
      }
      OptionParser.new do |opts|
        opts.banner = "Usage: visualize [options]"
        opts.on("-p package", "Visualize dependencies for specific package") do |package|
          options[:package] = package
        end
        opts.on("-o out_dir", "Output folder") do |out_dir|
          options[:out_dir] = out_dir
        end
        options[:help] = opts.help
      end.parse!(args)
      puts(options[:help])
      options
    end
  end
end
