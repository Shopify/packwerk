# frozen_string_literal: true
# typed: strict

#
# There are some known bugs in this cache:
# 1) The cache should be busted if the contents of `packwerk.yml` change, since custom associations can affect what is considered a violation
# 2) The cache should be busted if inflections change.
#
# In practice, we think these things change rarely enough that when they do change, a user can just run `rm -rf tmp/cache/packwerk` to reset the cache
#
module Packwerk
  class Cache
    extend T::Sig

    sig do
      params(
        files: T::Array[String],
        root_path: String,
        block: T.proc.params(untracked_files: T::Array[String]).returns(T::Array[RunContext::ProcessedFileResult])
      ).returns(T::Array[RunContext::ProcessedFileResult])
    end
    def self.with_cache(files, root_path:, &block)
      cache = Private.new(root_path: root_path)
      uncached_files = cache.files_without_cache_hits(files)
      Debug.out("Using cache - #{cache.cached_file_count} files are cached, #{uncached_files.count} are not")
      Debug.out("First 5 uncached files: #{uncached_files.first(5).inspect}")
      uncached_results = block.call(uncached_files)
      cache.cache_results(uncached_files, uncached_results)

      uncached_results + cache.cached_results
    end

    class Private
      extend T::Sig

      CACHE_DIR = T.let(Pathname.new("tmp/cache/packwerk"), Pathname)

      class CacheContents < T::Struct
        const :cache_digest, String
        const :result, RunContext::ProcessedFileResult
      end

      CACHE_SHAPE = T.type_alias do
        T::Hash[
          String,
          CacheContents
        ]
      end

      sig { params(root_path: String).void }
      def initialize(root_path:)
        FileUtils.mkdir_p(CACHE_DIR)
        @cache = T.let({}, CACHE_SHAPE)
        
        # The cache associated with each file is named by the digest of the file name (not contents).
        # Whether or not the cache is hit is based on the `cache_digest` key within each file (more below).
        Pathname.glob(CACHE_DIR.join('**')).each do |filecache_path|
          # We take the basename which is the file name digest
          @cache[filecache_path.basename.to_s] = YAML.load(filecache_path.read)
        end

        @root_path = root_path
        @files_by_digest = T.let({}, T::Hash[String, String])
      end

      sig { returns(T::Array[RunContext::ProcessedFileResult]) }
      def cached_results
        @cache.values.map(&:result)
      end

      sig { returns(Integer) }
      def cached_file_count
        @cache.keys.count
      end

      sig { params(files: T::Array[String]).returns(T::Array[String]) }
      def files_without_cache_hits(files)
        files.select do |file|
          if File.exist?(file)
            current_entry = @cache[digest_for_string(file)]
            if current_entry.nil?
              true
            else
              cached_digest = current_entry.cache_digest
              current_digest = digest_for_result(current_entry.result)
              # TODO: If there is a cache miss here, we should delete the old cache
              current_digest != cached_digest
            end
          else
            true
          end
        end
      end

      sig { params(uncached_files: T::Array[String], uncached_results: T::Array[RunContext::ProcessedFileResult]).void }
      def cache_results(uncached_files, uncached_results)
        uncached_results_by_file = uncached_results.group_by(&:file)
        Debug.out("Storing results in cache by digest...")
        uncached_files.each do |file|
          result = T.must(uncached_results_by_file.fetch(file).first)
          cache_contents = CacheContents.new(
            cache_digest: digest_for_result(result),
            result: result
          )

          CACHE_DIR.join(digest_for_string(file)).write YAML.dump(cache_contents)
        end
        Debug.out("Finished dumping into cache...")
      end

      sig { params(result: RunContext::ProcessedFileResult).returns(String) }
      def digest_for_result(result)
        all_inputs_to_digest = []
        #
        # Each file can create one "cache input." A cache input should contain ALL of the
        # inputs needed to know if we can reliably use the cached results for a given file.
        #
        # Remember that when a file is read, we look for each class, constant, and module,
        # and then use the ConstantResolver to find the source location of each constant.
        # We then find the source pack, and based on its configuration, we determine if there
        # is an result or not
        #
        # Therefore to know if we can reliably use the cached results, we need to know
        # if any of the following have changed:
        # 1) The entire file contents
        #   - The contents are what dictate what references there are, and therefore what results there are.
        #     If the file contents change, we need to reparse the file
        #
        all_inputs_to_digest << digest_for_file(result.file)
        # 2) The file contents of all of the source locations of all of the Packwerk::Reference.
        #   - Note that packwerk prevents ambiguous definitions, so for classes and modules, a "cache hit"
        #     here is simply that those files still exist. If they don't, it means the file has been moved and another
        #     pack now defines that class/module. However, for a constant, we need to confirm that the source location
        #     digest is the same, because the constant can be moved without file names changing.
        result.references.each do |reference|
          all_inputs_to_digest << if File.exist?(reference.constant.location)
            digest_for_file(reference.constant.location)
          else
            "constant location does not exist"
          end
        end
        # 3) The file contents of the package YMLs in any of the Packwerk::Reference
        #   - We need this because something can be a reference but not an result, and simply changing
        #     The setting for enforce_privacy can turn that Reference into an RunContext::ProcessedFileResult.
        result.references.each do |reference|
          all_inputs_to_digest << if reference.constant.package.yml.exist?
            digest_for_file(reference.constant.package.yml.to_s)
          else
            "constant pack does not exist"
          end
        end

        digest_for_string(all_inputs_to_digest.inspect)
      end

      sig { params(file: String).returns(String) }
      def digest_for_file(file)
        # We cache this to avoid unnecessary File IO
        @files_by_digest[file] ||= digest_for_string(File.read(file))
      end

      sig { params(str: String).returns(String) }
      def digest_for_string(str)
        # MD5 appears to be the fastest
        # https://gist.github.com/morimori/1330095
        Digest::MD5.hexdigest(str)
      end
    end

    class Debug
      extend T::Sig

      sig { params(out: String).void }
      def self.out(out)
        if ENV['DEBUG_PACKWERK_CACHE']
          puts out
        end
      end
    end


    private_constant :Debug
    private_constant :Private
  end
end
