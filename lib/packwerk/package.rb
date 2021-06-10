# typed: true
# frozen_string_literal: true

module Packwerk
  class Package
    include Comparable

    ROOT_PACKAGE_NAME = "."

    attr_reader :name, :dependencies

    def initialize(name:, config:)
      @name = name
      @config = config || {}
      @dependencies = Array(@config["dependencies"]).freeze
    end

    def enforce_privacy
      @config["enforce_privacy"]
    end

    def enforce_dependencies?
      @config["enforce_dependencies"] == true
    end

    def dependency?(package)
      @dependencies.include?(package.name)
    end

    def package_path?(path)
      return true if root?
      path.start_with?(@name)
    end

    def public_path
      @public_path ||= File.join(@name, user_defined_public_path || "app/public/")
    end

    def public_path?(path)
      path.start_with?(public_path)
    end

    def user_defined_public_path
      return unless @config["public_path"]
      return @config["public_path"] if @config["public_path"].end_with?("/")

      @config["public_path"] + "/"
    end

    def <=>(other)
      return nil unless other.is_a?(self.class)
      name <=> other.name
    end

    def eql?(other)
      self == other
    end

    def hash
      name.hash
    end

    def to_s
      name
    end

    def root?
      @name == ROOT_PACKAGE_NAME
    end
  end
end
