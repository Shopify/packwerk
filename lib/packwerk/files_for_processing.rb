# typed: strict
# frozen_string_literal: true

module Packwerk
  class FilesForProcessing
    extend T::Sig

    class << self
      extend T::Sig

      sig do
        params(
          relative_file_paths: T::Array[String],
          configuration: Configuration,
          ignore_nested_packages: T::Boolean
        ).returns(T::Array[String])
      end
      def fetch(relative_file_paths:, configuration:, ignore_nested_packages: false)
        new(relative_file_paths, configuration, ignore_nested_packages).files
      end
    end

    sig do
      params(
        relative_file_paths: T::Array[String],
        configuration: Configuration,
        ignore_nested_packages: T::Boolean
      ).void
    end
    def initialize(relative_file_paths, configuration, ignore_nested_packages)
      @relative_file_paths = relative_file_paths
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
      @custom_files ||= @relative_file_paths.flat_map do |relative_file_path|
        absolute_file_path = File.expand_path(relative_file_path, @configuration.root_path)
        if File.file?(absolute_file_path)
          absolute_file_path
        else
          custom_included_files(absolute_file_path)
        end
      end
    end

    sig { params(absolute_file_path: String).returns(T::Array[String]) }
    def custom_included_files(absolute_file_path)
      # Note, assuming include globs are always relative paths
      absolute_includes = @configuration.include.map do |glob|
        File.expand_path(glob, @configuration.root_path)
      end

      absolute_file_paths = Dir.glob([File.join(absolute_file_path, "**", "*")]).select do |absolute_path|
        absolute_includes.any? do |pattern|
          File.fnmatch?(pattern, absolute_path, File::FNM_EXTGLOB)
        end
      end

      if @ignore_nested_packages
        nested_packages_absolute_file_paths = Dir.glob(File.join(absolute_file_path, "*", "**", "package.yml"))
        nested_packages_absolute_globs = nested_packages_absolute_file_paths.map do |npp|
          npp.gsub("package.yml", "**/*")
        end
        nested_packages_absolute_globs.each do |absolute_glob|
          absolute_file_paths -= Dir.glob(absolute_glob)
        end
      end

      absolute_file_paths
    end

    sig { returns(T::Array[String]) }
    def configured_included_files
      absolute_file_paths_for_globs(@configuration.include)
    end

    sig { returns(T::Array[String]) }
    def configured_excluded_files
      absolute_file_paths_for_globs(@configuration.exclude)
    end

    sig { params(relative_globs: T::Array[String]).returns(T::Array[String]) }
    def absolute_file_paths_for_globs(relative_globs)
      relative_globs
        .flat_map { |glob| Dir[File.expand_path(glob, @configuration.root_path)] }
        .uniq
    end
  end
end
