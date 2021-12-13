# typed: true
# frozen_string_literal: true

require "pathname"
require "yaml"

module Packwerk
  class Configuration
    extend T::Sig

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
      :include, :exclude, :root_path, :package_paths, :custom_associations, :config_path
    )

    sig { returns(T::Array[String]) }
    attr_reader :load_paths

    sig { returns(Inflector) }
    attr_reader :inflector

    def initialize(configs = {}, config_path: nil)
      if configs["load_paths"]
        warning = <<~WARNING
          DEPRECATION WARNING: The 'load_paths' key in `packwerk.yml` is deprecated.
          This value is no longer cached, and you can remove the key from `packwerk.yml`.
        WARNING

        warn(warning)
      end

      inflection_file = File.expand_path(configs["inflections_file"] || "config/inflections.yml", @root_path)
      if configs["inflections_file"]
        warning = <<~WARNING
          DEPRECATION WARNING: The 'inflections_file' key in `packwerk.yml` is deprecated.
          This value is no longer cached, and you can remove the key from `packwerk.yml`.
          You can also delete #{configs["inflections_file"]}.
        WARNING

        warn(warning)
      end

      if Pathname.new(inflection_file).exist?
        warning = <<~WARNING
          DEPRECATION WARNING: Inflections YMLs in packwerk are now deprecated.
          This value is no longer cached, and you can now delete #{inflection_file}
        WARNING

        warn(warning)
      end

      @include = configs["include"] || DEFAULT_INCLUDE_GLOBS
      @exclude = configs["exclude"] || DEFAULT_EXCLUDE_GLOBS
      root = config_path ? File.dirname(config_path) : "."
      @root_path = File.expand_path(root)
      @package_paths = configs["package_paths"] || "**/"
      @custom_associations = configs["custom_associations"] || []
      @parallel = configs.key?("parallel") ? configs["parallel"] : true

      @config_path = config_path

      result = RailsDependencies.fetch_load_paths_and_apply_inflections!
      @load_paths ||= result.load_paths
      @inflector ||= result.inflector
    end

    def parallel?
      @parallel
    end
  end
end
