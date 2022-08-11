# typed: strict
# frozen_string_literal: true

require "bundler"

module Packwerk
  # Extracts the load paths from the analyzed application so that we can map constant names to paths.
  module ApplicationLoadPaths
    class << self
      extend T::Sig

      sig { params(root: String, environment: String).returns(T::Array[String]) }
      def extract_relevant_paths(root, environment)
        require_application(root, environment)
        all_paths = extract_application_autoload_paths
        relevant_paths = filter_relevant_paths(all_paths)
        assert_load_paths_present(relevant_paths)
        relative_path_strings(relevant_paths)
      end

      sig { returns(T::Array[String]) }
      def extract_application_autoload_paths
        Rails.autoloaders.inject({}) do |h, loader|
          h.merge(loader.root_dirs)
        end.keys
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

      sig { params(load_paths: T::Array[Pathname], rails_root: Pathname).returns(T::Array[String]) }
      def relative_path_strings(load_paths, rails_root: Rails.root)
        load_paths.map { |path| Pathname.new(path).relative_path_from(rails_root).to_s }
      end

      private

      sig { params(root: String, environment: String).void }
      def require_application(root, environment)
        environment_file = "#{root}/config/environment"

        if File.file?("#{environment_file}.rb")
          ENV["RAILS_ENV"] ||= environment

          require environment_file
        else
          raise "A Rails application could not be found in #{root}"
        end
      end

      sig { params(paths: T::Array[Pathname]).void }
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
