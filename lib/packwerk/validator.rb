# typed: strict
# frozen_string_literal: true

require "constant_resolver"
require "pathname"
require "yaml"

module Packwerk
  module Validator
    extend T::Sig
    extend T::Helpers
    extend ActiveSupport::Autoload

    autoload :Result

    abstract!

    class << self
      extend T::Sig

      #: (Class[top] base) -> void
      def included(base)
        validators << base
      end

      #: -> Array[Validator]
      def all
        load_defaults
        T.cast(validators.map(&:new), T::Array[Validator])
      end

      private

      #: -> void
      def load_defaults
        require("packwerk/validators/dependency_validator")
      end

      #: -> Array[Class[top]]
      def validators
        @validators ||= [] #: Array[Class[top]]?
      end
    end

    # @abstract
    #: -> Array[String]
    def permitted_keys = raise NotImplementedError, "Abstract method called"

    # @abstract
    #: (PackageSet package_set, Configuration configuration) -> Validator::Result
    def call(package_set, configuration) = raise NotImplementedError, "Abstract method called"

    #: (Configuration configuration, untyped setting) -> untyped
    def package_manifests_settings_for(configuration, setting)
      package_manifests(configuration).map { |f| [f, (YAML.load_file(File.join(f)) || {})[setting]] }
    end

    #: (Configuration configuration, ?(Array[String] | String)? glob_pattern) -> Array[String]
    def package_manifests(configuration, glob_pattern = nil)
      glob_pattern ||= package_glob(configuration)
      PackageSet.package_paths(configuration.root_path, glob_pattern, configuration.exclude)
        .map { |f| File.realpath(f) }
    end

    #: (Configuration configuration) -> (Array[String] | String)
    def package_glob(configuration)
      configuration.package_paths
    end

    #: (
    #|   Array[Validator::Result] results,
    #|   ?separator: String,
    #|   ?before_errors: String,
    #|   ?after_errors: String
    #| ) -> Validator::Result
    def merge_results(results, separator: "\n", before_errors: "", after_errors: "")
      results.reject!(&:ok?)

      if results.empty?
        Validator::Result.new(ok: true)
      else
        Validator::Result.new(
          ok: false,
          error_value: [
            before_errors,
            separator.lstrip,
            results.map(&:error_value).join(separator),
            after_errors,
          ].join,
        )
      end
    end

    #: (Configuration configuration, String path) -> Pathname
    def relative_path(configuration, path)
      Pathname.new(path).relative_path_from(configuration.root_path)
    end
  end
end
