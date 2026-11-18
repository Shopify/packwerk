# typed: true
# frozen_string_literal: true

require "test_helper"
require "support/rails_test_helper"

module Packwerk
  class CacheTest < Minitest::Test
    include FactoryHelper
    include ApplicationFixtureHelper
    include TypedMock

    setup do
      setup_application_fixture
      use_template(:minimal)
      open_app_file("packwerk.yml") { |file| file.write("") }
    end

    teardown do
      Cache.new(
        enable_cache: true,
        config_path: "packwerk.yml",
        cache_directory: Pathname.new("tmp/cache/packwerk")
      ).bust_cache!
      teardown_application_fixture
    end

    test "#todo writes to the cache" do
      filepath = Pathname.pwd.join("path/of/exile.rb")
      FileUtils.mkdir_p(filepath.dirname)
      filepath.write("class MyClass; end")

      unresolved_references = [
        UnresolvedReference.new(
          constant_name: "MyConstant",
          namespace_path: [],
          relative_path: "path/of_exile.rb",
          source_location: Node::Location.new(5, 5)
        ),
      ]

      FileProcessor.any_instance.stubs(:references_from_ast).returns(unresolved_references)
      FilesForProcessing.any_instance.stubs(:files).returns(Set.new([filepath.to_s]))
      configuration = Configuration.from_path
      configuration.stubs(cache_enabled?: true)
      out = StringIO.new

      update_command = Commands::UpdateTodoCommand.new(
        [],
        configuration: configuration,
        out: out,
        err_out: StringIO.new,
        progress_formatter: Formatters::ProgressFormatter.new(out),
        offenses_formatter: configuration.offenses_formatter
      )

      update_command.run
      update_command.run

      cache_files = Pathname.pwd.join(Pathname.new("tmp/cache/packwerk")).glob("**")
      assert_equal cache_files.count, 3

      digest_file = Pathname.new("tmp/cache/packwerk").join(Digest::MD5.hexdigest(filepath.to_s))
      cached_result = Cache::CacheContents.deserialize(digest_file.read)
      assert_equal cached_result.unresolved_references, unresolved_references
    end

    test "#with_cache treats an unparseable cache entry as a miss" do
      filepath = write_cache_source_file
      unresolved_references = [sample_unresolved_reference]
      cache = build_cache
      digest_file = cache_directory.join(Digest::MD5.hexdigest(filepath.to_s))

      ["", "{not-json"].each do |corrupt_contents|
        digest_file.write(corrupt_contents)

        result = cache.with_cache(filepath.to_s) { unresolved_references }

        assert_equal unresolved_references, result
        cached_result = Cache::CacheContents.deserialize(digest_file.read)
        assert_equal unresolved_references, cached_result.unresolved_references
      end

      second_result = cache.with_cache(filepath.to_s) { flunk("expected the rewritten cache entry to hit") }
      assert_equal unresolved_references, second_result
    end

    test "#with_cache treats a cache entry that disappears while being read as a miss" do
      filepath = write_cache_source_file
      unresolved_references = [sample_unresolved_reference]
      cache = build_cache
      digest_file = cache_directory.join(Digest::MD5.hexdigest(filepath.to_s))
      digest_file.write("present but removed before the read")

      Pathname.any_instance.stubs(:read).raises(Errno::ENOENT)
      begin
        result = cache.with_cache(filepath.to_s) { unresolved_references }
      ensure
        Pathname.any_instance.unstub(:read)
      end

      assert_equal unresolved_references, result
      cached_result = Cache::CacheContents.deserialize(digest_file.read)
      assert_equal unresolved_references, cached_result.unresolved_references
    end

    test "cache entries and digest files are published by renaming a complete temporary file" do
      filepath = write_cache_source_file
      unresolved_references = [sample_unresolved_reference]
      recorded_renames = []
      original_rename = File.method(:rename)

      File.stub(:rename, ->(from, to) {
        recorded_renames << [from, to, File.binread(from)] if to.start_with?(cache_directory.to_s)
        original_rename.call(from, to)
      }) do
        cache = build_cache
        cache.with_cache(filepath.to_s) { unresolved_references }
      end

      entry_path = cache_directory.join(Digest::MD5.hexdigest(filepath.to_s)).to_s
      expected_targets = [
        cache_directory.join("packwerk_yml").to_s,
        cache_directory.join("inflections").to_s,
        entry_path,
      ]
      assert_equal expected_targets.sort, recorded_renames.map { |_from, to, _contents| to }.sort

      recorded_renames.each do |from, to, contents|
        assert_equal cache_directory.to_s, File.dirname(from)
        refute_equal from, to
        assert_equal contents, File.binread(to)
      end

      cached_result = Cache::CacheContents.deserialize(File.binread(entry_path))
      assert_equal unresolved_references, cached_result.unresolved_references
      assert_equal ["inflections", "packwerk_yml", File.basename(entry_path)].sort,
        cache_directory.children.map { |path| path.basename.to_s }.sort
    end

    private

    def cache_directory
      Pathname.new("tmp/cache/packwerk")
    end

    def build_cache
      Cache.new(
        enable_cache: true,
        config_path: "packwerk.yml",
        cache_directory: Pathname.new("tmp/cache/packwerk"),
      )
    end

    def write_cache_source_file
      filepath = Pathname.pwd.join("path/of/exile.rb")
      FileUtils.mkdir_p(filepath.dirname)
      filepath.write("class MyClass; end")
      filepath
    end

    def sample_unresolved_reference
      UnresolvedReference.new(
        constant_name: "MyConstant",
        namespace_path: [],
        relative_path: "path/of_exile.rb",
        source_location: Node::Location.new(5, 5),
      )
    end
  end
end
