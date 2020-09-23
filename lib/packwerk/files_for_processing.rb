# typed: true
# frozen_string_literal: true

module Packwerk
  class FilesForProcessing
    class << self
      def fetch(paths:, configuration:)
        new(paths, configuration).files
      end
    end

    def initialize(paths, configuration)
      @paths = paths
      @configuration = configuration
    end

    def files
      include_files = if custom_files.empty?
        configured_included_files
      else
        custom_files
      end

      include_files - configured_excluded_files
    end

    private

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

    def custom_included_files(path)
      # Note, assuming include globs are always relative paths
      absolute_includes = @configuration.include.map do |glob|
        File.expand_path(glob, @configuration.root_path)
      end

      Dir.glob([File.join(path, "**", "*")]).select do |file_path|
        absolute_includes.any? do |pattern|
          File.fnmatch?(pattern, file_path, File::FNM_EXTGLOB)
        end
      end
    end

    def configured_included_files
      files_for_globs(@configuration.include)
    end

    def configured_excluded_files
      files_for_globs(@configuration.exclude)
    end

    def files_for_globs(globs)
      globs
        .flat_map { |glob| Dir[File.expand_path(glob, @configuration.root_path)] }
        .uniq
    end
  end
end
