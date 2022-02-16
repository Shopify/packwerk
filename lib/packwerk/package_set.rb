# typed: strict
# frozen_string_literal: true

require "pathname"

module Packwerk
  PathSpec = T.type_alias { T.any(String, T::Array[String]) }

  # This trie performantly allows us to identify what file a package is in.
  # It stores packages in a Trie data structure. A Trie places each "entry" in a package path
  # into one node, with pointers to child nodes that contain the subsequent entries.
  # For example, if our packs are:
  # `app/services/my_pack`, `app/services/my_other_pack`, `packs/my_pack`, `packs/my_other_pack`, and `packs/my_pack/nested/my_nested_pack`,
  # then our trie looks like this (created using https://asciiflow.com)
  #
  #                      ┌────┐
  #             ┌────────┤root├───────────┐
  #             │        └────┘           │
  #             │                         │
  #           ┌─▼─┐                  ┌────▼───┐
  #           │app│                  │packages├──┐
  #           └─┬─┘                  └┬───────┘  │
  #             │                     │          │
  #      ┌──────▼──┐     ┌────────────▼───┐  ┌───▼──┐
  #      │services │     │my_other_package│  │nested├───┐
  #      └─┬───────┘     └────────────────┘  └──────┘   │
  #        │                                            │
  # ┌──────▼───┐                                 ┌──────▼──────────┐
  # │my_package│                                 │my_nested_package│
  # └──────────┘                                 └─────────────────┘
  #
  # When we need to identify what pack a file belongs to, we split it up into its entries, and the most jumps through the tree we will have to make is proportional
  # to the height of the tree, won't be greater than the length of the longest package.
  #
  class PackageNameTrie
    extend T::Sig

    Letter = T.type_alias { String }

    class TrieNode
      extend T::Sig

      sig do
        params(
          children: T::Hash[Letter, TrieNode],
          end_of_package_name: T::Boolean
        ).void
      end
      def initialize(children, end_of_package_name)
        @children = children
        @end_of_package_name = end_of_package_name
      end

      sig { returns(T::Boolean) }
      attr_accessor :end_of_package_name

      sig { returns(T::Hash[Letter, TrieNode]) }
      attr_accessor :children

      sig { params(package_name: String).void }
      def insert(package_name)
        current_tree_node = T.let(self, TrieNode)
        filepath_entries = package_name.split("/")
        filepath_entries.each_with_index do |filepath_entry, index|
          current_tree_node.children[filepath_entry] ||= TrieNode.new({}, false)
          current_tree_node = T.must(current_tree_node.children[filepath_entry])
          if filepath_entries.length - 1 == index
            current_tree_node.end_of_package_name = true
          end
        end
      end
    end

    sig do
      params(
        root_node: TrieNode
      ).void
    end
    def initialize(root_node)
      @root_node = root_node
    end

    sig { params(packages: T::Array[Package]).returns(PackageNameTrie) }
    def self.from_packages(packages)
      root_node = TrieNode.new({}, false)
      packages.each do |package|
        unless package.root?
          root_node.insert(package.name)
        end
      end

      PackageNameTrie.new(root_node)
    end

    sig { params(file_path: String).returns(String) }
    def longest_package_name_that_is_superset_of(file_path)
      current_node = @root_node
      possible_packs = T.let([], T::Array[String])
      traversed = []
      filepath_entries = file_path.split("/")
      filepath_entries.each do |filepath_entry|
        if current_node.end_of_package_name
          possible_packs << traversed.join("/")
        end

        traversed << filepath_entry
        new_node = current_node.children[filepath_entry]

        # Once there are no more nodes, stop iterating
        break if new_node.nil?

        current_node = new_node
      end

      # This way we match the longest pack name that is a prefix of the filepath
      # We fall back to the root if no pack matches
      longest_pack_name = possible_packs.last
      longest_pack_name || Package::ROOT_PACKAGE_NAME
    end
  end

  private_constant :PackageNameTrie

  # A set of {Packwerk::Package}s as well as methods to parse packages from the filesystem.
  class PackageSet
    extend T::Sig
    extend T::Generic
    include Enumerable

    Elem = type_member(fixed: Package)

    PACKAGE_CONFIG_FILENAME = "package.yml"

    class << self
      extend T::Sig

      sig { params(root_path: String, package_pathspec: T.nilable(PathSpec)).returns(PackageSet) }
      def load_all_from(root_path, package_pathspec: nil)
        package_paths = package_paths(root_path, package_pathspec || "**")

        packages = package_paths.map do |path|
          root_relative = path.dirname.relative_path_from(root_path)
          Package.new(name: root_relative.to_s, config: YAML.load_file(path))
        end

        create_root_package_if_none_in(packages)

        new(packages)
      end

      sig do
        params(
          root_path: String,
          package_pathspec: PathSpec,
          exclude_pathspec: T.nilable(PathSpec)
        ).returns(T::Array[Pathname])
      end
      def package_paths(root_path, package_pathspec, exclude_pathspec = [])
        exclude_pathspec = Array(exclude_pathspec).dup
          .push(Bundler.bundle_path.join("**").to_s)
          .map { |glob| File.expand_path(glob) }

        glob_patterns = Array(package_pathspec).map do |pathspec|
          File.join(root_path, pathspec, PACKAGE_CONFIG_FILENAME)
        end

        Dir.glob(glob_patterns)
          .map { |path| Pathname.new(path).cleanpath }
          .reject { |path| exclude_path?(exclude_pathspec, path) }
      end

      private

      sig { params(packages: T::Array[Package]).void }
      def create_root_package_if_none_in(packages)
        return if packages.any?(&:root?)
        packages << Package.new(name: Package::ROOT_PACKAGE_NAME, config: nil)
      end

      sig { params(globs: T::Array[String], path: Pathname).returns(T::Boolean) }
      def exclude_path?(globs, path)
        globs.any? do |glob|
          path.realpath.fnmatch(glob, File::FNM_EXTGLOB)
        end
      end
    end

    sig { returns(T::Hash[String, Package]) }
    attr_reader :packages

    sig { params(packages: T::Array[Package]).void }
    def initialize(packages)
      # We want to match more specific paths first
      sorted_packages = packages.sort_by { |package| -package.name.length }
      @package_trie = T.let(PackageNameTrie.from_packages(packages), PackageNameTrie)
      packages = sorted_packages.each_with_object({}) { |package, hash| hash[package.name] = package }
      @packages = T.let(packages, T::Hash[String, Package])
      @package_from_path = T.let({}, T::Hash[String, Package])
    end

    sig { override.params(blk: T.proc.params(arg0: Package).returns(T.untyped)).returns(T.untyped) }
    def each(&blk)
      packages.values.each(&blk)
    end

    sig { params(name: String).returns(T.nilable(Package)) }
    def fetch(name)
      packages[name]
    end

    sig { params(file_path: T.any(Pathname, String)).returns(T.nilable(Package)) }
    def package_from_path(file_path)
      filepath_string = file_path.to_s
      @package_from_path[filepath_string] ||= T.must(
        packages[@package_trie.longest_package_name_that_is_superset_of(filepath_string)]
      )
    end
  end
end
