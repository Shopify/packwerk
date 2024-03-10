# typed: strict
# frozen_string_literal: true

require "pathname"
require "bundler"

module Packwerk

  # A set of {Packwerk::Package}s as well as methods to parse packages from the filesystem.
  class PackageSet
    extend T::Sig
    extend T::Generic
    include Enumerable

    Elem = type_member { { fixed: Package } }

    PACKAGE_CONFIG_FILENAME = "package.yml"

    class << self
      extend T::Sig

      sig do
        params(root_path: String, package_pathspec: T.nilable(PackagePaths::PathSpec),
          scan_for_packages_outside_of_app_dir: T.nilable(T::Boolean)).returns(PackageSet)
      end
      def load_all_from(root_path, package_pathspec: nil, scan_for_packages_outside_of_app_dir: false)
        package_paths = PackagePaths.new(root_path, package_pathspec || "**", nil, scan_for_packages_outside_of_app_dir)

        packages = package_paths.all_paths.map do |path|
          root_relative = path.dirname.relative_path_from(root_path)
          Package.new(name: root_relative.to_s, config: YAML.load_file(path, fallback: nil))
        end

        create_root_package_if_none_in(packages)

        new(packages)
      end

      private

      sig { params(packages: T::Array[Package]).void }
      def create_root_package_if_none_in(packages)
        return if packages.any?(&:root?)

        packages << Package.new(name: Package::ROOT_PACKAGE_NAME, config: nil)
      end

      
    end

    sig { returns(T::Hash[String, Package]) }
    attr_reader :packages

    sig { params(packages: T::Array[Package]).void }
    def initialize(packages)
      # We want to match more specific paths first
      sorted_packages = packages.sort_by { |package| -package.name.length }
      packages = sorted_packages.each_with_object({}) { |package, hash| hash[package.name] = package }
      @packages = T.let(packages, T::Hash[String, Package])
      @package_from_path = T.let({}, T::Hash[String, T.nilable(Package)])
    end

    sig { override.params(blk: T.proc.params(arg0: Package).returns(T.untyped)).returns(T.untyped) }
    def each(&blk)
      packages.values.each(&blk)
    end

    sig { params(name: String).returns(T.nilable(Package)) }
    def fetch(name)
      packages[name]
    end

    sig { params(file_path: T.any(Pathname, String)).returns(Package) }
    def package_from_path(file_path)
      path_string = file_path.to_s
      @package_from_path[path_string] ||= T.must(packages.values.find { |package| package.package_path?(path_string) })
    end
  end
end
