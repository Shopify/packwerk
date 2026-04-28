# typed: strict
# frozen_string_literal: true

require "pathname"
require "yaml"

module Packwerk
  class Configuration
    extend T::Sig

    class << self
      extend T::Sig

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
    DEFAULT_INCLUDE_GLOBS = T.let(["**/*.{rb,rake,erb}"], T::Array[String])
    DEFAULT_EXCLUDE_GLOBS = T.let(["{bin,node_modules,script,tmp,vendor}/**/*"], T::Array[String])

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
      @include = T.let(configs["include"] || DEFAULT_INCLUDE_GLOBS, T::Array[String])
      @exclude = T.let(configs["exclude"] || DEFAULT_EXCLUDE_GLOBS, T::Array[String])
      root = config_path ? File.dirname(config_path) : "."
      @root_path = T.let(File.expand_path(root), String)
      @package_paths = T.let(configs["package_paths"] || "**/", T.any(String, T::Array[String]))
      @custom_associations = T.let((configs["custom_associations"] || []).map(&:to_sym), T::Array[Symbol])
      @associations_exclude = T.let(configs["associations_exclude"] || [], T::Array[String])
      @parallel = T.let(configs.key?("parallel") ? configs["parallel"] : true, T::Boolean)
      @cache_enabled = T.let(configs.key?("cache") ? configs["cache"] : false, T::Boolean)
      @cache_directory = T.let(Pathname.new(configs["cache_directory"] || "tmp/cache/packwerk"), Pathname)
      @config_path = config_path

      @offenses_formatter_identifier = T.let(
        configs["offenses_formatter"] || Formatters::DefaultOffensesFormatter::IDENTIFIER, String
      )

      if configs.key?("require")
        configs["require"].each do |require_directive|
          ExtensionLoader.load(require_directive, @root_path)
        end
      end
    end

    #: -> Hash[String, Module[top]]
    def load_paths
      @load_paths ||= T.let(
        RailsLoadPaths.for(@root_path, environment: "test"),
        T.nilable(T::Hash[String, T::Module[T.anything]]),
      )
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
  end
end
