# frozen_string_literal: true
# typed: strict

module Packwerk
  class Cache
    extend T::Sig

    sig do
      params(
        files: T::Array[String],
        root_path: String,
        block: T.proc.params(untracked_files: T::Array[String]).returns(T::Array[Offense])
      ).returns(T::Array[Offense])
    end
    def self.with_cache(files, root_path:, &block)
      cache = Private.new(root_path: root_path)
      uncached_files = cache.uncached_files(files)
      puts("Using cache - #{cache.cached_file_count} files are cached, #{uncached_files.count} are not")
      puts "First 5 uncached files: #{uncached_files.first(5).inspect}"
      uncached_offenses = block.call(uncached_files)
      cache.cache_results(uncached_files, uncached_offenses)
      uncached_offenses + cache.cached_offenses
    end

    class Private
      extend T::Sig

      CACHE_DIR = T.let(Pathname.new("tmp/cache/packwerk"), Pathname)
      CACHE_FILE = T.let(CACHE_DIR.join("all.txt"), Pathname)

      sig { params(root_path: String).void }
      def initialize(root_path:)
        FileUtils.mkdir_p(CACHE_DIR)
        @cache = T.let({}, T::Hash[String, T::Array[Offense]])
        if CACHE_FILE.exist?
          @cache = T.let(YAML.load(CACHE_FILE.read), T::Hash[String, T::Array[Offense]])
        end

        @root_path = root_path
        @files_by_digest = T.let({}, T::Hash[String, String])
      end

      sig { returns(T::Array[Offense]) }
      def cached_offenses
        @cache.values.flatten.compact
      end

      sig { returns(Integer) }
      def cached_file_count
        @cache.keys.count
      end

      sig { params(files: T::Array[String]).returns(T::Array[String]) }
      def uncached_files(files)
        files.select do |file|
          @cache[digest_for_file(file)].nil?
        end
      end

      sig { params(uncached_files: T::Array[String], uncached_offenses: T::Array[Offense]).void }
      def cache_results(uncached_files, uncached_offenses)
        uncached_offenses_by_file = uncached_offenses.group_by(&:file)
        puts("Storing offenses in cache by digest...")
        uncached_files.each do |file|
          relative_path = Pathname.new(file).relative_path_from(@root_path)
          # Offense#file returns a relative path, but the uncached files are a list of absolute paths
          @cache[digest_for_file(file)] = uncached_offenses_by_file[relative_path] || []
        end
        puts("Dumping into cache...")
        CACHE_FILE.write(YAML.dump(@cache))
        puts("Finished dumping into cache...")
      end

      sig { params(file: String).returns(String) }
      def digest_for_file(file)
        @files_by_digest[file] ||= Digest::SHA256.hexdigest(File.read(file))
      end
    end

    private_constant :Private
  end
end
