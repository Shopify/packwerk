# frozen_string_literal: true
# typed: strict

#
# There are some known bugs in this cache:
# 1) The cache should be busted if the contents of `packwerk.yml` change, since custom associations
# can affect what is considered a violation
# 2) The cache should be busted if inflections change.
#
# In practice, we think these things change rarely enough that when they do change, a user can
# just run `rm -rf tmp/cache/packwerk` to reset the cache, but we may want a `bin/packwerk bust_cache`.
# If we want to be fancier, we could even automatically bust the cache when we detect a change to these files
# (by taking the digest of inflections and packwerk.yml).
#
module Packwerk
  class Cache
    CACHE_DIR = T.let(Pathname.new("tmp/cache/packwerk"), Pathname)

    extend T::Sig

    class CacheContents < T::Struct
      const :file_contents_digest, String
      const :partially_qualified_references, T::Array[PartiallyQualifiedReference]
    end

    CACHE_SHAPE = T.type_alias do
      T::Hash[
        String,
        CacheContents
      ]
    end

    sig { void }
    def self.bust_cache!
      FileUtils.rm_rf(CACHE_DIR)
    end

    sig { void }
    def initialize
      FileUtils.mkdir_p(CACHE_DIR)
      @cache = T.let({}, CACHE_SHAPE)
      @files_by_digest = T.let({}, T::Hash[String, String])
    end

    sig do
      params(
        file_path: String,
        block: T.proc.returns(T::Array[PartiallyQualifiedReference])
      ).returns(T::Array[PartiallyQualifiedReference])
    end
    def with_cache(file_path, &block)
      return block.call if ENV["EXPERIMENTAL_PACKWERK_CACHE"].nil?

      cache_location = CACHE_DIR.join(digest_for_string(file_path))
      cache_contents = cache_location.exist? ? T.let(YAML.load(cache_location.read), CacheContents) : nil
      if !cache_contents.nil? && cache_contents.file_contents_digest == digest_for_file(file_path)
        Debug.out("Cache hit for #{file_path}")
        cache_contents.partially_qualified_references
      else
        Debug.out("Cache miss for #{file_path}")
        partially_qualified_references = block.call
        cache_contents = CacheContents.new(
          file_contents_digest: digest_for_file(file_path),
          partially_qualified_references: partially_qualified_references,
        )
        cache_location.write(YAML.dump(cache_contents))
        partially_qualified_references
      end
    end

    sig { params(file: String).returns(String) }
    def digest_for_file(file)
      # We cache this to avoid unnecessary File IO
      @files_by_digest[file] ||= digest_for_string(File.exist?(file) ? File.read(file) : "file does not exist")
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
      if ENV["DEBUG_PACKWERK_CACHE"]
        puts(out)
      end
    end
  end

  private_constant :Debug
end
