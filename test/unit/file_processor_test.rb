# typed: false
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class FileProcessorTest < Minitest::Test
    setup do
      @run_context = mock
      @node_processor = mock
      @file_processor = ::Packwerk::FileProcessor.new(run_context: @run_context)
    end

    test "#call visits all nodes in a file path with no offenses" do
      @run_context.expects(:node_processor_for).returns(@node_processor)
      @node_processor.expects(:call).twice.returns(nil)

      offenses = tempfile(name: "foo", content: "def food_bar; end") do |file_path|
        @file_processor.call(file_path)
      end

      assert_empty offenses
    end

    test "#call visits a node in file path with an offense" do
      location = mock
      location.stubs(line: 3, column: 22)

      offense = stub(location: location, file: "tempfile", message: "Use of unassigned variable")
      @run_context.expects(:node_processor_for).returns(@node_processor)
      @node_processor.expects(:call).returns(offense)

      offenses = tempfile(name: "foo", content: "a_variable_name") do |file_path|
        @file_processor.call(file_path)
      end

      assert_equal 1, offenses.length

      offense = offenses.first
      assert_equal "tempfile", offense.file
      assert_equal 3, offense.location.line
      assert_equal 22, offense.location.column
      assert_equal "Use of unassigned variable", offense.message
    end

    test "#call provides node processor with the correct ancestors" do
      offense = mock
      @run_context.expects(:node_processor_for).returns(@node_processor)
      @node_processor.expects(:call).with do |node, ancestors:|
        Node.class?(node) && # class Hello; world; end
          Node.class_or_module_name(node) == "Hello" &&
          ancestors.empty?
      end
      @node_processor.expects(:call).with do |node, ancestors:|
        parent = ancestors.first # class Hello; world; end
        Node.constant?(node) && # Hello
          Node.constant_name(node) == "Hello" &&
          ancestors.length == 1 &&
          Node.class?(parent) &&
          Node.class_or_module_name(parent) == "Hello"
      end
      @node_processor.expects(:call).with do |node, ancestors:|
        parent = ancestors.first # class Hello; world; end
        Node.method_call?(node) && # world
          Node.method_name(node) == :world &&
          ancestors.length == 1 &&
          Node.class?(parent) &&
          Node.class_or_module_name(parent) == "Hello"
      end.returns(offense)

      offenses = tempfile(name: "hello_world", content: "class Hello; world; end") do |file_path|
        @file_processor.call(file_path)
      end

      assert_equal [offense], offenses
    end

    test "#call reports no offenses for an empty file" do
      offenses = tempfile(name: "foo", content: "# no fun") do |file_path|
        @file_processor.call(file_path)
      end

      assert_empty offenses
    end

    test "#call with an invalid syntax doesn't parse node" do
      run_context = mock.expects(:node_processor_for).never
      file_processor = ::Packwerk::FileProcessor.new(run_context: run_context)

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
