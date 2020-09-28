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
        new(YAML.load_file(path), config_path: path)
      end
    end

    DEFAULT_CONFIG_PATH = "packwerk.yml"
    DEFAULT_INCLUDE_GLOBS = ["**/*.{rb,rake,erb}"]
    DEFAULT_EXCLUDE_GLOBS = ["{bin,node_modules,script,tmp}/**/*"]

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
      @load_paths = configs["load_paths"] || all_application_autoload_paths
      @inflections_file = File.expand_path(configs["inflections_file"] || "config/inflections.yml", @root_path)

      @config_path = config_path
    end

    def all_application_autoload_paths
      return [] unless defined?(::Rails)

      all_paths = Rails.application.railties
        .select { |railtie| railtie.is_a?(Rails::Engine) }
        .push(Rails.application)
        .flat_map do |engine|
        (engine.config.autoload_paths + engine.config.eager_load_paths + engine.config.autoload_once_paths).uniq
      end

      rails_root_match = Rails.root.join("**").to_s
      bundle_path_match = Bundler.bundle_path.join("**").to_s

      all_paths = all_paths.map do |path_string|
        # ignore paths outside of the Rails root and vendored gems
        path = Pathname.new(path_string)
        if path.exist? && path.realpath.fnmatch(rails_root_match) && !path.realpath.fnmatch(bundle_path_match)
          path.relative_path_from(Rails.root).to_s
        end
      end

      all_paths.compact.tap do |paths|
        if paths.empty?
          raise <<~EOS
            No autoload paths have been set up in your Rails app. This is likely a bug, and
            packwerk is unlikely to work correctly without any autoload paths.

            You can follow the Rails guides on setting up load paths, or manually configure
            them in `packwerk.yml` with `load_paths`.
          EOS
        end
      end
    end
  end
end
