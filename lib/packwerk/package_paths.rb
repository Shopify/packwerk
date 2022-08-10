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
      ).void
    end
    def initialize(root_path, package_pathspec, exclude_pathspec = nil)
      @root_path = root_path
      @package_pathspec = package_pathspec
      @exclude_pathspec = exclude_pathspec
    end

    def all_paths
      exclude_pathspec = Array(@exclude_pathspec).dup
        .push(Bundler.bundle_path.join("**").to_s)
        .map { |glob| File.expand_path(glob) }

      paths_to_scan = [@root_path]

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
  end
end
