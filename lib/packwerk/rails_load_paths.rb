# typed: strict
# frozen_string_literal: true

require "bundler"
gem "railties", ">= 6.0"
require "rails/railtie"

module Packwerk
  # Extracts the load paths from the analyzed application so that we can map constant names to paths.
  module RailsLoadPaths
    class << self
      extend T::Sig

      #: (String root, environment: String) -> Hash[String, Module[top]]
      def for(root, environment:)
        require_application(root, environment)
        all_paths = extract_application_autoload_paths
        relevant_paths = filter_relevant_paths(all_paths)
        assert_load_paths_present(relevant_paths)
        relative_path_strings(relevant_paths)
      end

      private

      #: -> Hash[String, Module[top]]
      def extract_application_autoload_paths
        Rails.autoloaders.inject({}) do |h, loader|
          h.merge(loader.dirs(namespaces: true))
        end
      end

      #: (Hash[String, Module[top]] all_paths, ?bundle_path: Pathname, ?rails_root: Pathname) -> Hash[Pathname, Module[top]]
      def filter_relevant_paths(all_paths, bundle_path: Bundler.bundle_path, rails_root: Rails.root)
        bundle_path_match = bundle_path.join("**")
        rails_root_match = rails_root.join("**")

        all_paths
          .transform_keys { |path| Pathname.new(path).expand_path }
          .select { |path| path.fnmatch(rails_root_match.to_s) } # path needs to be in application directory
          .reject { |path| path.fnmatch(bundle_path_match.to_s) } # reject paths from vendored gems
      end

      #: (Hash[Pathname, Module[top]] load_paths, ?rails_root: Pathname) -> Hash[String, Module[top]]
      def relative_path_strings(load_paths, rails_root: Rails.root)
        load_paths.transform_keys { |path| Pathname.new(path).relative_path_from(rails_root).to_s }
      end

      #: (String root, String environment) -> void
      def require_application(root, environment)
        environment_file = "#{root}/config/environment"

        if File.file?("#{environment_file}.rb")
          ENV["RAILS_ENV"] ||= environment

          require environment_file
        else
          raise "A Rails application could not be found in #{root}"
        end
      end

      #: (Hash[untyped, Module[top]] paths) -> void
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
