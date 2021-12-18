# frozen_string_literal: true
require "test_helper"
require "rails_test_helper"

module Packwerk
  class CacheTest < Minitest::Test
    include FactoryHelper
    include ApplicationFixtureHelper

    setup do
      ENV['EXPERIMENTAL_PACKWERK_CACHE'] = '1'
      setup_application_fixture
    end

    teardown do
      teardown_application_fixture
      Cache.bust_cache!
    end

    test "#update_deprecations writes to the cache" do
      use_template(:minimal)
      offense = Offense.new(file: "path/of/exile.rb", message: "something")

      processed_file_result = RunContext::ProcessedFileResult.new(
        file: build_reference.relative_path,
        references: [build_reference],
        offenses: [offense],
      )

      RunContext.any_instance.stubs(:process_file).returns(processed_file_result)
      OffenseCollection.any_instance.expects(:dump_deprecated_references_files).once

      parse_run = Packwerk::ParseRun.new(files: ["path/of/exile.rb"], configuration: Configuration.from_path)
      result = parse_run.update_deprecations

      cache_files = Pathname.pwd.join(Cache::CACHE_DIR).glob('**')
      assert_equal cache_files.count, 1

      cached_result = YAML.load(cache_files.first.read).result
      assert_equal cached_result.references, processed_file_result.references
      assert_equal cached_result.offenses.count, processed_file_result.offenses.count
      assert_equal cached_result.offenses.first.message, processed_file_result.offenses.first.message
      assert_equal cached_result.file, processed_file_result.file
    end

    test "#update_deprecations reads from the cache if there is a cache hit" do
      use_template(:minimal)
      offense = Offense.new(file: "path/of/exile.rb", message: "something")

      processed_file_result = RunContext::ProcessedFileResult.new(
        file: "path/of/exile.rb",
        references: [build_reference],
        offenses: [offense],
      )

      # We expect process file once, but dump twice
      RunContext.any_instance.expects(:process_file).returns(processed_file_result).once
      OffenseCollection.any_instance.expects(:dump_deprecated_references_files).twice

      configuration = Configuration.new({ "parallel" => false })
      parse_run = Packwerk::ParseRun.new(files: ["path/of/exile.rb"], configuration: configuration)

      result = parse_run.update_deprecations
      result = parse_run.update_deprecations
    end

    test "#update_deprecations does not read from the cache if the constant package YML has changed" do
      use_template(:minimal)
      offense = Offense.new(file: "path/of/exile.rb", message: "something")

      reference = build_reference
      processed_file_result = RunContext::ProcessedFileResult.new(
        file: "path/of/exile.rb",
        references: [reference],
        offenses: [offense],
      )

      RunContext.any_instance.expects(:process_file).returns(processed_file_result).twice
      OffenseCollection.any_instance.expects(:dump_deprecated_references_files).twice

      configuration = Configuration.new({ "parallel" => false })
      parse_run = Packwerk::ParseRun.new(files: ["path/of/exile.rb"], configuration: configuration)

      result = parse_run.update_deprecations
      FileUtils.mkdir_p(reference.constant.package.directory)
      reference.constant.package.yml.write("some change!")

      result = parse_run.update_deprecations
    end

    test "#update_deprecations does not read from the cache if the constant file location has changed" do
      use_template(:minimal)
      offense = Offense.new(file: "path/of/exile.rb", message: "something")

      reference = build_reference
      processed_file_result = RunContext::ProcessedFileResult.new(
        file: "path/of/exile.rb",
        references: [reference],
        offenses: [offense],
      )

      RunContext.any_instance.expects(:process_file).returns(processed_file_result).twice
      OffenseCollection.any_instance.expects(:dump_deprecated_references_files).twice

      configuration = Configuration.new({ "parallel" => false })
      parse_run = Packwerk::ParseRun.new(files: ["path/of/exile.rb"], configuration: configuration)

      result = parse_run.update_deprecations
      constant_pathname = Pathname.new(reference.constant.location)
      FileUtils.mkdir_p(constant_pathname.dirname)
      constant_pathname.write("some change!")

      result = parse_run.update_deprecations
    end

    test "#update_deprecations does not read from the cache if the file itself has changed" do
      use_template(:minimal)
      offense = Offense.new(file: "path/of/exile.rb", message: "something")

      reference = build_reference
      processed_file_result = RunContext::ProcessedFileResult.new(
        file: "path/of/exile.rb",
        references: [reference],
        offenses: [offense],
      )

      RunContext.any_instance.expects(:process_file).returns(processed_file_result).twice
      OffenseCollection.any_instance.expects(:dump_deprecated_references_files).twice

      configuration = Configuration.new({ "parallel" => false })
      parse_run = Packwerk::ParseRun.new(files: ["path/of/exile.rb"], configuration: configuration)

      result = parse_run.update_deprecations
      file_path = Pathname.new('path/of/exile.rb')
      FileUtils.mkdir_p(file_path.dirname)
      file_path.write("some change!")

      result = parse_run.update_deprecations
    end

    test "#update_deprecations will delete the old cache if it no longer is a hit for the file" do
      use_template(:minimal)
      offense = Offense.new(file: "path/of/exile.rb", message: "something")

      reference = build_reference
      processed_file_result = RunContext::ProcessedFileResult.new(
        file: "path/of/exile.rb",
        references: [reference],
        offenses: [offense],
      )

      RunContext.any_instance.expects(:process_file).returns(processed_file_result).twice
      OffenseCollection.any_instance.expects(:dump_deprecated_references_files).twice

      configuration = Configuration.new({ "parallel" => false })
      parse_run = Packwerk::ParseRun.new(files: ["path/of/exile.rb"], configuration: configuration)

      cache_files = Pathname.pwd.join(Cache::CACHE_DIR).glob('**')
      assert_equal cache_files.count, 0

      result = parse_run.update_deprecations

      cache_files = Pathname.pwd.join(Cache::CACHE_DIR).glob('**')
      assert_equal cache_files.count, 1
      
      file_path = Pathname.new('path/of/exile.rb')
      FileUtils.mkdir_p(file_path.dirname)
      file_path.write("some change!")
      
      result = parse_run.update_deprecations

      new_cache_files = Pathname.pwd.join(Cache::CACHE_DIR).glob('**')
      assert_equal cache_files.count, 1
      refute_equal YAML.load(new_cache_files.first.read), YAML.load(cache_files.first.read)
    end
  end
end
