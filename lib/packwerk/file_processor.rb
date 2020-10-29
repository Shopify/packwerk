# typed: false
# frozen_string_literal: true

require "ast/node"

require "packwerk/node"
require "packwerk/offense"
require "packwerk/parsers"
require "packwerk/node/node_factory"

module Packwerk
  class FileProcessor
    class UnknownFileTypeResult < Offense
      def initialize(file:)
        super(file: file, message: "unknown file type")
      end
    end

    def initialize(run_context:, parser_factory: nil)
      @run_context = run_context
      @parser_factory = parser_factory || Packwerk::Parsers::Factory.instance
    end

    def call(file_path)
      parser = @parser_factory.for_path(file_path)
      return [UnknownFileTypeResult.new(file: file_path)] if parser.nil?

      node = File.open(file_path, "r", external_encoding: Encoding::UTF_8) do |file|
        parser.call(io: file, file_path: file_path)
      rescue Parsers::ParseError => e
        return [e.result]
      end

      result = []
      if node
        node = NodeFactory.for(node)
        @node_processor = @run_context.node_processor_for(filename: file_path, ast_node: node)
        node_visitor = Packwerk::NodeVisitor.new(node_processor: @node_processor)
        node_visitor.visit(node, ancestors: [], result: result)
      end
      result
    end
  end
end
