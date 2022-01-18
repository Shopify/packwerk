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
      extend T::Sig

      const :file_contents_digest, String
      const :unresolved_references, T::Array[UnresolvedReference]

      # A previous implementation used YAML.dump and YAML.load.
      # Although these are much cleaner, the YAML loading code can handle arbitrary object
      # shapes and therefore is a lot more complex (thus, slower)
      # By having a simple serialization and deserialization, we save some time here.
      sig { returns(String) }
      def serialize
        to_json
      end

      sig { params(serialized_cache_contents: String).returns(CacheContents) }
      def self.deserialize(serialized_cache_contents)
        cache_contents_json = JSON.parse(serialized_cache_contents)
        unresolved_references = cache_contents_json["unresolved_references"].map do |json|
          UnresolvedReference.new(
            json["constant_name"],
            json["namespace_path"],
            json["relative_path"],
            Node::Location.new(json["source_location"]["line"], json["source_location"]["column"],)
          )
        end

        CacheContents.new(
          file_contents_digest: cache_contents_json["file_contents_digest"],
          unresolved_references: unresolved_references,
        )
      end
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

    sig { params(enable_cache: T::Boolean).void }
    def initialize(enable_cache:)
      @enable_cache = enable_cache
      FileUtils.mkdir_p(CACHE_DIR)
      @cache = T.let({}, CACHE_SHAPE)
      @files_by_digest = T.let({}, T::Hash[String, String])
    end

    sig do
      params(
        file_path: String,
        block: T.proc.returns(T::Array[UnresolvedReference])
      ).returns(T::Array[UnresolvedReference])
    end
    def with_cache(file_path, &block)
      return block.call unless @enable_cache

      cache_location = CACHE_DIR.join(digest_for_string(file_path))
      cache_contents = if cache_location.exist?
        T.let(CacheContents.deserialize(cache_location.read),
          CacheContents)
      end
      file_contents_digest = digest_for_file(file_path)

      if !cache_contents.nil? && cache_contents.file_contents_digest == file_contents_digest
        Debug.out("Cache hit for #{file_path}")
        cache_contents.unresolved_references
      else
        Debug.out("Cache miss for #{file_path}")
        unresolved_references = block.call
        cache_contents = CacheContents.new(
          file_contents_digest: file_contents_digest,
          unresolved_references: unresolved_references,
        )
        cache_location.write(cache_contents.serialize)
        unresolved_references
      end
    end

    sig { params(file: String).returns(String) }
    def digest_for_file(file)
      digest_for_string(File.read(file))
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
