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

    sig { returns(String) }
    attr_reader :name
    sig { returns(T::Array[String]) }
    attr_reader :dependencies

    sig { params(name: String, config: T.nilable(T.any(T::Hash[T.untyped, T.untyped], FalseClass))).void }
    def initialize(name:, config:)
      @name = name
      @config = T.let(config || {}, T::Hash[T.untyped, T.untyped])
      @dependencies = T.let(Array(@config["dependencies"]).freeze, T::Array[String])
    end

    sig { returns(T.nilable(T.any(T::Boolean, T::Array[String]))) }
    def enforce_privacy
      @config["enforce_privacy"]
    end

    sig { returns(T::Boolean) }
    def enforce_dependencies?
      @config["enforce_dependencies"] == true
    end

    sig { params(package: Package).returns(T::Boolean) }
    def dependency?(package)
      @dependencies.include?(package.name)
    end

    sig { params(path: String).returns(T::Boolean) }
    def package_path?(path)
      return true if root?
      path.start_with?(@name)
    end

    sig { returns(Pathname) }
    def directory
      @directory = T.let(@directory, T.nilable(Pathname))
      @directory ||= if root?
        Pathname.new(".")
      else
        Pathname.new(@name)
      end
    end

    sig { returns(Pathname) }
    def yml
      @yml = T.let(@yml, T.nilable(Pathname))
      @yml ||= directory.join(PackageSet::PACKAGE_CONFIG_FILENAME)
    end

    sig { returns(String) }
    def public_path
      @public_path = T.let(@public_path, T.nilable(String))
      @public_path ||= directory.join(user_defined_public_path || "app/public/").to_s
    end

    sig { params(path: String).returns(T::Boolean) }
    def public_path?(path)
      path.start_with?(public_path)
    end

    sig { returns(T.nilable(String)) }
    def user_defined_public_path
      return unless @config["public_path"]
      return @config["public_path"] if @config["public_path"].end_with?("/")

      @config["public_path"] + "/"
    end

    sig { params(other: T.untyped).returns(T.nilable(Integer)) }
    def <=>(other)
      return nil unless other.is_a?(self.class)
      name <=> other.name
    end

    sig { params(other: T.untyped).returns(T::Boolean) }
    def eql?(other)
      self == other
    end

    sig { returns(Integer) }
    def hash
      name.hash
    end

    sig { returns(String) }
    def to_s
      name
    end

    sig { returns(T::Boolean) }
    def root?
      @name == ROOT_PACKAGE_NAME
    end
  end
end
