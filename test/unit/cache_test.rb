# frozen_string_literal: true
require "test_helper"
require "rails_test_helper"

module Packwerk
  class CacheTest < Minitest::Test
    include FactoryHelper
    include ApplicationFixtureHelper
    include TypedMock

    setup do
      setup_application_fixture
    end

    teardown do
      teardown_application_fixture
      Cache.bust_cache!
    end

    test "#update_deprecations writes to the cache" do
      use_template(:minimal)
      filepath = Pathname.pwd.join("path/of/exile.rb")
      FileUtils.mkdir_p(filepath.dirname)
      filepath.write("class MyClass; end")

      unresolved_references = [
        UnresolvedReference.new(
          "MyConstant",
          [],
          "path/of_exile.rb",
          Node::Location.new(5, 5)
        ),
      ]

      FileProcessor.any_instance.stubs(:references_from_ast).returns(unresolved_references)
      configuration = Configuration.from_path
      configuration.stubs(experimental_cache?: true)

      parse_run = Packwerk::ParseRun.new(files: [filepath.to_s], configuration: configuration)
      parse_run.update_deprecations
      parse_run.update_deprecations

      cache_files = Pathname.pwd.join(Cache::CACHE_DIR).glob("**")
      assert_equal cache_files.count, 1

      cached_result = Cache::CacheContents.deserialize(cache_files.first.read)
      assert_equal cached_result.unresolved_references, unresolved_references
    end
  end
end
