# typed: strict
# frozen_string_literal: true

module Packwerk
  # The basic unit of modularity for packwerk; a folder that has been declared to define a package.
  # The package contains all constants defined in files in this folder and all subfolders that are not packages
  # themselves.
  class Package
    extend T::Sig
    include Comparable

    ROOT_PACKAGE_NAME = "."

    #: String
    attr_reader :name

    #: Array[String]
    attr_reader :dependencies

    #: Hash[untyped, untyped]
    attr_reader :config

    #: (name: String, ?config: Hash[String, untyped]?) -> void
    def initialize(name:, config: nil)
      @name = name
      @config = T.let(config || {}, T::Hash[String, T.untyped])
      @dependencies = T.let(Array(@config["dependencies"]).freeze, T::Array[String])
      @public_path = T.let(nil, T.nilable(String))
    end

    #: -> bool
    def enforce_dependencies?
      [true, "strict"].include?(@config["enforce_dependencies"])
    end

    #: (Package package) -> bool
    def dependency?(package)
      @dependencies.include?(package.name)
    end

    #: (String path) -> bool
    def package_path?(path)
      return true if root?

      path.start_with?(@name + "/")
    end

    #: (untyped other) -> Integer?
    def <=>(other)
      return nil unless other.is_a?(self.class)

      name <=> other.name
    end

    #: (untyped other) -> bool
    def eql?(other)
      self == other
    end

    #: -> Integer
    def hash
      name.hash
    end

    #: -> String
    def to_s
      name
    end

    #: -> bool
    def root?
      @name == ROOT_PACKAGE_NAME
    end
  end
end
