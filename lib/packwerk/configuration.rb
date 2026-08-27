# typed: strict
# frozen_string_literal: true

require "pathname"
require "yaml"

module Packwerk
  class Configuration
    class << self
      #: (?String path) -> Configuration
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

      #: (String path) -> Configuration
      def from_packwerk_config(path)
        new(
          YAML.load_file(path) || {},
          config_path: path
        )
      end
    end

    DEFAULT_CONFIG_PATH = "packwerk.yml"
    DEFAULT_INCLUDE_GLOBS = ["**/*.{rb,rake,erb}"] #: Array[String]
    DEFAULT_EXCLUDE_GLOBS = ["{bin,node_modules,script,tmp,vendor}/**/*"] #: Array[String]

    #: Array[String]
    attr_reader(:include)

    #: Array[String]
    attr_reader(:exclude)

    #: String
    attr_reader(:root_path)

    #: (String | Array[String])
    attr_reader(:package_paths)

    #: Array[Symbol]
    attr_reader(:custom_associations)

    #: Array[String]
    attr_reader(:associations_exclude)

    #: String?
    attr_reader(:config_path)

    #: Pathname
    attr_reader(:cache_directory)

    #: bool
    attr_writer(:parallel)

    #: (?Hash[String, untyped] configs, ?config_path: String?) -> void
    def initialize(configs = {}, config_path: nil)
      @include = configs["include"] || DEFAULT_INCLUDE_GLOBS #: Array[String]
      @exclude = configs["exclude"] || DEFAULT_EXCLUDE_GLOBS #: Array[String]
      root = config_path ? File.dirname(config_path) : "."
      @root_path = File.expand_path(root) #: String
      @package_paths = configs["package_paths"] || "**/" #: (String | Array[String])
      @custom_associations = (configs["custom_associations"] || []).map(&:to_sym) #: Array[Symbol]
      @associations_exclude = configs["associations_exclude"] || [] #: Array[String]
      @parallel = configs.key?("parallel") ? configs["parallel"] : true #: bool
      @cache_enabled = configs.key?("cache") ? configs["cache"] : false #: bool
      @cache_directory = Pathname.new(configs["cache_directory"] || "tmp/cache/packwerk") #: Pathname
      @config_path = config_path

      @offenses_formatter_identifier = configs["offenses_formatter"] || Formatters::DefaultOffensesFormatter::IDENTIFIER #: String
      @config_load_paths = parse_config_load_paths(configs["load_paths"]) #: Array[String]

      if configs.key?("require")
        configs["require"].each do |require_directive|
          ExtensionLoader.load(require_directive, @root_path)
        end
      end
    end

    #: -> Hash[String, Module[top]]
    def load_paths
      @load_paths ||= resolve_load_paths #: Hash[String, Module[top]]?
    end

    #: -> bool
    def parallel?
      @parallel
    end

    #: -> OffensesFormatter
    def offenses_formatter
      OffensesFormatter.find(@offenses_formatter_identifier)
    end

    #: -> bool
    def cache_enabled?
      @cache_enabled
    end

    private

    #: -> Hash[String, Module[top]]
    def resolve_load_paths
      if @config_load_paths.any? # non-Rails app
        load_paths_from_config
      elsif File.file?(File.join(@root_path, "config", "environment.rb")) # Rails app
        RailsLoadPaths.for(@root_path, environment: "test")
      else
        raise <<~MSG
          Packwerk could not determine your application's load paths.

          If this is a Rails application, run Packwerk from its root directory
          (the one containing config/environment.rb).

          Otherwise, list your Zeitwerk root directories explicitly in packwerk.yml, e.g.:

            load_paths:
              - app
              - lib
        MSG
      end
    end

    #: -> Hash[String, Module[top]]
    def load_paths_from_config
      paths = @config_load_paths
        .flat_map { |glob| Dir.glob(glob, base: @root_path) }
        .select { |path| File.directory?(File.join(@root_path, path)) }
        .uniq

      if paths.empty?
        raise <<~MSG
          The `load_paths` configured in packwerk.yml did not match any directories:
            #{@config_load_paths.inspect}

          Packwerk will not work correctly without any load paths.
        MSG
      end

      paths.to_h { |path| [path, Object] }
    end

    #: (untyped raw) -> Array[String]
    def parse_config_load_paths(raw)
      return [] if raw.nil?

      unless raw.is_a?(Array) && raw.all?(String)
        raise ArgumentError, "`load_paths` in packwerk.yml must be a list of strings, got: #{raw.inspect}"
      end

      raw
    end
  end
end
