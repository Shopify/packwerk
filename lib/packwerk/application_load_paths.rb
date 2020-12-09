# typed: strict
# frozen_string_literal: true

require "bundler"

module Packwerk
  module ApplicationLoadPaths
    class << self
      extend T::Sig

      sig { returns(T::Array[String]) }
      def extract_relevant_paths
        assert_application_booted
        all_paths = extract_application_autoload_paths
        relevant_paths = filter_relevant_paths(all_paths)
        assert_load_paths_present(relevant_paths)
        relative_path_strings(relevant_paths)
      end

      sig { void }
      def assert_application_booted
        raise "The application needs to be booted to extract load paths" unless defined?(::Rails)
      end

      sig { returns(T::Array[String]) }
      def extract_application_autoload_paths
        Rails.application.railties
          .select { |railtie| railtie.is_a?(Rails::Engine) }
          .push(Rails.application)
          .flat_map do |engine|
            paths = (engine.config.autoload_paths + engine.config.eager_load_paths + engine.config.autoload_once_paths)
            paths.map(&:to_s).uniq
          end
      end

      sig do
        params(all_paths: T::Array[String], bundle_path: Pathname, rails_root: Pathname)
          .returns(T::Array[Pathname])
      end
      def filter_relevant_paths(all_paths, bundle_path: Bundler.bundle_path, rails_root: Rails.root)
        bundle_path_match = bundle_path.join("**")
        rails_root_match = rails_root.join("**")

        all_paths
          .map { |path| Pathname.new(path).expand_path }
          .select { |path| path.fnmatch(rails_root_match.to_s) } # path needs to be in application directory
          .reject { |path| path.fnmatch(bundle_path_match.to_s) } # reject paths from vendored gems
      end

      sig { params(paths: T::Array[Pathname], rails_root: Pathname).returns(T::Array[String]) }
      def relative_path_strings(paths, rails_root: Rails.root)
        paths
          .map { |path| path.relative_path_from(rails_root).to_s }
          .uniq
      end

      sig { params(paths: T::Array[T.untyped]).void }
      def assert_load_paths_present(paths)
        if paths.empty?
          raise <<~EOS
            We could not extract autoload paths from your Rails app. This is likely a configuration error.
            Packwerk will not work correctly without any autoload paths.
          EOS
        end
      end
    end
  end
end
