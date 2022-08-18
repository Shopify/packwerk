# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class FileProcessorTest < Minitest::Test
    include FactoryHelper
    include TypedMock

    setup do
      @node_processor_factory = typed_mock
      @node_processor = typed_mock
      @cache = Cache.new(
        enable_cache: false,
        cache_directory: Pathname.new("tmp/cache/packwerk"),
        config_path: "packwerk.yml"
      )
      @file_processor = ::Packwerk::FileProcessor.new(node_processor_factory: @node_processor_factory, cache: @cache)
    end

    test "#call visits all nodes in a file path with no references" do
      @node_processor_factory.expects(:for).returns(@node_processor)
      @node_processor.expects(:call).twice.returns(nil)

      processed_file = tempfile(name: "foo", content: "def food_bar; end") do |file_path|
        @file_processor.call(file_path)
      end

      assert_equal processed_file.unresolved_references, []
      assert_equal processed_file.offenses, []
    end

    test "#call visits a node in file path with an reference" do
      unresolved_reference = UnresolvedReference.new("SomeName", [], "tempfile", Node::Location.new(3, 22))
      @node_processor_factory.expects(:for).returns(@node_processor)
      @node_processor.expects(:call).returns(unresolved_reference)

      processed_file = tempfile(name: "foo", content: "a_variable_name") do |file_path|
        @file_processor.call(file_path)
      end

      assert_equal 0, processed_file.offenses.count
      references = processed_file.unresolved_references
      assert_equal 1, references.length

      reference = references.first

      assert_equal "tempfile", reference.relative_path
      assert_equal 3, reference.source_location.line
      assert_equal 22, reference.source_location.column
    end

    test "#call provides node processor with the correct ancestors" do
      reference = typed_mock
      @node_processor_factory.expects(:for).returns(@node_processor)
      @node_processor.expects(:call).with do |node, ancestors|
        NodeHelpers.class?(node) && # class Hello; world; end
          NodeHelpers.class_or_module_name(node) == "Hello" &&
          ancestors.empty?
      end.returns(nil)
      @node_processor.expects(:call).with do |node, ancestors|
        parent = ancestors.first # class Hello; world; end
        NodeHelpers.constant?(node) && # Hello
          NodeHelpers.constant_name(node) == "Hello" &&
          ancestors.length == 1 &&
          NodeHelpers.class?(parent) &&
          NodeHelpers.class_or_module_name(parent) == "Hello"
      end.returns(nil)
      @node_processor.expects(:call).with do |node, ancestors|
        parent = ancestors.first # class Hello; world; end
        NodeHelpers.method_call?(node) && # world
          NodeHelpers.method_name(node) == :world &&
          ancestors.length == 1 &&
          NodeHelpers.class?(parent) &&
          NodeHelpers.class_or_module_name(parent) == "Hello"
      end.returns(reference)

      processed_file = tempfile(name: "hello_world", content: "class Hello; world; end") do |file_path|
        @file_processor.call(file_path)
      end

      assert_equal processed_file.unresolved_references, [reference]
      assert_equal processed_file.offenses, []
    end

    test "#call reports no references for an empty file" do
      processed_file = tempfile(name: "foo", content: "# no fun") do |file_path|
        @file_processor.call(file_path)
      end

      assert_equal processed_file.unresolved_references, []
      assert_equal processed_file.offenses, []
    end

    test "#call with an invalid syntax doesn't parse node" do
      @node_processor_factory.expects(:for).never
      file_processor = ::Packwerk::FileProcessor.new(
        node_processor_factory: @node_processor_factory,
        cache: Cache.new(
          enable_cache: false,
          cache_directory: Pathname.new("tmp/cache/packwerk"),
          config_path: "packwerk.yml"
        )
      )

      tempfile(name: "foo", content: "def error") do |file_path|
        file_processor.call(file_path)
      end
    end

    test "#call with a path that can't be parsed outputs error message" do
      processed_file = @file_processor.call("what/kind/of/file.ami")
      assert_equal 0, processed_file.unresolved_references.count
      offenses = processed_file.offenses
      assert_equal 1, offenses.length
      assert_equal "what/kind/of/file.ami", offenses.first.file
      assert_equal "unknown file type", offenses.first.message
    end

    private

    def tempfile(name:, content:)
      Tempfile.create([name, ".rb"]) do |file|
        file.write(content)
        file.flush

        yield(file.path)
      end
    end
  end
end
