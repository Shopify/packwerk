# typed: strict
# frozen_string_literal: true

module Packwerk
  class FilesForProcessing
    extend T::Sig

    class << self
      extend T::Sig

      sig do
        params(
          paths: T::Array[String],
          configuration: Configuration,
          ignore_nested_packages: T::Boolean
        ).returns(T::Array[String])
      end
      def fetch(paths:, configuration:, ignore_nested_packages: false)
        new(paths, configuration, ignore_nested_packages).files
      end
    end

    sig do
      params(
        paths: T::Array[String],
        configuration: Configuration,
        ignore_nested_packages: T::Boolean
      ).void
    end
    def initialize(paths, configuration, ignore_nested_packages)
      @paths = paths
      @configuration = configuration
      @ignore_nested_packages = ignore_nested_packages
      @custom_files = T.let(nil, T.nilable(T::Array[String]))
    end

    sig { returns(T::Array[String]) }
    def files
      include_files = if custom_files.empty?
        configured_included_files
      else
        custom_files
      end

      include_files - configured_excluded_files
    end

    private

    sig { returns(T::Array[String]) }
    def custom_files
      @custom_files ||= @paths.flat_map do |path|
        path = File.expand_path(path, @configuration.root_path)
        if File.file?(path)
          path
        else
          custom_included_files(path)
        end
      end
    end

    sig { params(path: String).returns(T::Array[String]) }
    def custom_included_files(path)
      # Note, assuming include globs are always relative paths
      absolute_includes = @configuration.include.map do |glob|
        File.expand_path(glob, @configuration.root_path)
      end

      files = Dir.glob([File.join(path, "**", "*")]).select do |file_path|
        absolute_includes.any? do |pattern|
          File.fnmatch?(pattern, file_path, File::FNM_EXTGLOB)
        end
      end

      if @ignore_nested_packages
        nested_packages_paths = Dir.glob(File.join(path, "*", "**", "package.yml"))
        nested_packages_globs = nested_packages_paths.map { |npp| npp.gsub("package.yml", "**/*") }
        nested_packages_globs.each do |glob|
          files -= Dir.glob(glob)
        end
      end

      files
    end

    sig { returns(T::Array[String]) }
    def configured_included_files
      files_for_globs(@configuration.include)
    end

    sig { returns(T::Array[String]) }
    def configured_excluded_files
      files_for_globs(@configuration.exclude)
    end

    sig { params(globs: T::Array[String]).returns(T::Array[String]) }
    def files_for_globs(globs)
      globs
        .flat_map { |glob| Dir[File.expand_path(glob, @configuration.root_path)] }
        .uniq
    end
  end
end
