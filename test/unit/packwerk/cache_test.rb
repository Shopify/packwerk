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
  end
end
