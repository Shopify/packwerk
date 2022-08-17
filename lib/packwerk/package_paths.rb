# typed: strict
# frozen_string_literal: true

require "pathname"
require "bundler"

module Packwerk
  class PackagePaths
    PACKAGE_CONFIG_FILENAME = "package.yml"
    PathSpec = T.type_alias { T.any(String, T::Array[String]) }

    extend T::Sig
    extend T::Generic

    sig do
      params(
        root_path: String,
        package_pathspec: T.nilable(PathSpec),
        exclude_pathspec: T.nilable(PathSpec),
        scan_for_packages_outside_of_app_dir: T.nilable(T::Boolean)
      ).void
    end
    def initialize(root_path, package_pathspec, exclude_pathspec = nil, scan_for_packages_outside_of_app_dir = false)
      @root_path = root_path
      @package_pathspec = package_pathspec
      @exclude_pathspec = exclude_pathspec
      @scan_for_packages_outside_of_app_dir = scan_for_packages_outside_of_app_dir
    end

    sig {returns(T::Array[Pathname])}
    def all_paths
      exclude_pathspec = Array(@exclude_pathspec).dup
        .push(Bundler.bundle_path.join("**").to_s)
        .map { |glob| File.expand_path(glob) }

      paths_to_scan = if @scan_for_packages_outside_of_app_dir
        engine_paths_to_scan.push(@root_path)
      else
        [@root_path]
      end

      glob_patterns = paths_to_scan.product(Array(@package_pathspec)).map do |path, pathspec|
        File.join(path, pathspec, PACKAGE_CONFIG_FILENAME)
      end

      Dir.glob(glob_patterns)
        .map { |path| Pathname.new(path).cleanpath }
        .reject { |path| exclude_path?(exclude_pathspec, path) }
    end

    private

    sig { params(globs: T::Array[String], path: Pathname).returns(T::Boolean) }
    def exclude_path?(globs, path)
      globs.any? do |glob|
        path.realpath.fnmatch(glob, File::FNM_EXTGLOB)
      end
    end

    sig { returns(T::Array[String]) }
    def engine_paths_to_scan
      bundle_path_match = Bundler.bundle_path.join("**")

      Rails.application.railties
        .select { |r| r.is_a?(Rails::Engine) }
        .map { |r| Pathname.new(r.root).expand_path }
        .reject { |path| path.fnmatch(bundle_path_match.to_s) } # reject paths from vendored gems
        .map(&:to_s)
    end
  end
end
