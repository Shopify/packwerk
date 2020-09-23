# typed: true
# frozen_string_literal: true

require "pathname"

require "packwerk/package"

module Packwerk
  class PackageSet
    include Enumerable

    PACKAGE_CONFIG_FILENAME = "package.yml"

    class << self
      def load_all_from(root_path, package_pathspec: nil)
        package_paths = package_paths(root_path, package_pathspec || "**")

        packages = package_paths.map do |path|
          root_relative = path.dirname.relative_path_from(root_path)
          Package.new(name: root_relative.to_s, config: YAML.load_file(path))
        end

        create_root_package_if_none_in(packages)

        new(packages)
      end

      private

      def package_paths(root_path, package_pathspec)
        Dir.glob(File.join(root_path, package_pathspec, PACKAGE_CONFIG_FILENAME))
          .map! { |path| Pathname.new(path) }
      end

      def create_root_package_if_none_in(packages)
        return if packages.any?(&:root?)
        packages << Package.new(name: Package::ROOT_PACKAGE_NAME, config: nil)
      end
    end

    def initialize(packages)
      # We want to match more specific paths first
      sorted_packages = packages.sort_by { |package| -package.name.length }
      @packages = sorted_packages.each_with_object({}) { |package, hash| hash[package.name] = package }
    end

    def each(&blk)
      @packages.values.each(&blk)
    end

    def fetch(name)
      @packages[name]
    end

    def package_from_path(file_path)
      @packages.values.find { |package| package.package_path?(file_path) }
    end
  end
end
