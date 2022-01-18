# typed: false
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class FileProcessorTest < Minitest::Test
    include FactoryHelper
    include TypedMock

    setup do
      @node_processor_factory = typed_mock
      @node_processor = typed_mock
      @cache = Cache.new(enable_cache: false, config_path: "packwerk.yml")
      @file_processor = ::Packwerk::FileProcessor.new(node_processor_factory: @node_processor_factory, cache: @cache)
    end

    test "#call visits all nodes in a file path with no references" do
      @node_processor_factory.expects(:for).returns(@node_processor)
      @node_processor.expects(:call).twice.returns(nil)

      references = tempfile(name: "foo", content: "def food_bar; end") do |file_path|
        @file_processor.call(file_path)
      end

      assert_empty references
    end

    test "#call visits a node in file path with an reference" do
      reference = build_reference(path: "tempfile", source_location: Packwerk::Node::Location.new(3, 22))

      @node_processor_factory.expects(:for).returns(@node_processor)
      @node_processor.expects(:call).returns(reference)

      references = tempfile(name: "foo", content: "a_variable_name") do |file_path|
        @file_processor.call(file_path)
      end

      assert_equal 1, references.length

      reference = references.first

      assert_equal "tempfile", reference.relative_path
      assert_equal 3, reference.source_location.line
      assert_equal 22, reference.source_location.column
    end

    test "#call provides node processor with the correct ancestors" do
      reference = mock
      @node_processor_factory.expects(:for).returns(@node_processor)
      @node_processor.expects(:call).with do |node, ancestors|
        Node.class?(node) && # class Hello; world; end
          Node.class_or_module_name(node) == "Hello" &&
          ancestors.empty?
      end.returns(nil)
      @node_processor.expects(:call).with do |node, ancestors|
        parent = ancestors.first # class Hello; world; end
        Node.constant?(node) && # Hello
          Node.constant_name(node) == "Hello" &&
          ancestors.length == 1 &&
          Node.class?(parent) &&
          Node.class_or_module_name(parent) == "Hello"
      end.returns(nil)
      @node_processor.expects(:call).with do |node, ancestors|
        parent = ancestors.first # class Hello; world; end
        Node.method_call?(node) && # world
          Node.method_name(node) == :world &&
          ancestors.length == 1 &&
          Node.class?(parent) &&
          Node.class_or_module_name(parent) == "Hello"
      end.returns(reference)

      references = tempfile(name: "hello_world", content: "class Hello; world; end") do |file_path|
        @file_processor.call(file_path)
      end

      assert_equal [reference], references
    end

    test "#call reports no references for an empty file" do
      references = tempfile(name: "foo", content: "# no fun") do |file_path|
        @file_processor.call(file_path)
      end

      assert_empty references
    end

    test "#call with an invalid syntax doesn't parse node" do
      @node_processor_factory.expects(:for).never
      file_processor = ::Packwerk::FileProcessor.new(node_processor_factory: @node_processor_factory,
cache: Cache.new(enable_cache: false, config_path: "packwerk.yml"))

      tempfile(name: "foo", content: "def error") do |file_path|
        file_processor.call(file_path)
      end
    end

    test "#call with a path that can't be parsed outputs error message" do
      results = @file_processor.call("what/kind/of/file.ami")

      assert_equal 1, results.length
      assert_equal "what/kind/of/file.ami", results.first.file
      assert_equal "unknown file type", results.first.message
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
