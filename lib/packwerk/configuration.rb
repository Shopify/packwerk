# typed: true
# frozen_string_literal: true

require "pathname"
require "yaml"

module Packwerk
  class Configuration
    class << self
      def from_path(path = Dir.pwd)
        raise ArgumentError, "#{File.expand_path(path)} does not exist" unless File.exist?(path)

        default_packwerk_path = File.join(path, DEFAULT_CONFIG_PATH)

        if File.file?(default_packwerk_path)
          from_packwerk_config(default_packwerk_path)
        else
          new
        end
      end

      private

      def from_packwerk_config(path)
        new(
          YAML.load_file(path) || {},
          config_path: path
        )
      end
    end

    DEFAULT_CONFIG_PATH = "packwerk.yml"
    DEFAULT_INCLUDE_GLOBS = ["**/*.{rb,rake,erb}"]
    DEFAULT_EXCLUDE_GLOBS = ["{bin,node_modules,script,tmp,vendor}/**/*"]

    attr_reader(
      :include, :exclude, :root_path, :package_paths, :custom_associations, :load_paths, :inflections_file,
      :config_path,
    )

    def initialize(configs = {}, config_path: nil)
      @include = configs["include"] || DEFAULT_INCLUDE_GLOBS
      @exclude = configs["exclude"] || DEFAULT_EXCLUDE_GLOBS
      root = config_path ? File.dirname(config_path) : "."
      @root_path = File.expand_path(root)
      @package_paths = configs["package_paths"] || "**/"
      @custom_associations = configs["custom_associations"] || []
      @load_paths = configs["load_paths"] || []
      @inflections_file = File.expand_path(configs["inflections_file"] || "config/inflections.yml", @root_path)

      @config_path = config_path
    end
  end
end
