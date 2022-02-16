# typed: true
# frozen_string_literal: true

require "ast/node"

module Packwerk
  class FileProcessor
    extend T::Sig

    class UnknownFileTypeResult < Offense
      def initialize(file:)
        super(file: file, message: "unknown file type")
      end
    end

    sig do
      params(
        node_processor_factory: NodeProcessorFactory,
        cache: Cache,
        parser_factory: T.nilable(Parsers::Factory)
      ).void
    end
    def initialize(node_processor_factory:, cache:, parser_factory: nil)
      @node_processor_factory = node_processor_factory
      @cache = cache
      @parser_factory = parser_factory || Packwerk::Parsers::Factory.instance
    end

    sig do
      params(file_path: String).returns(
        T::Array[
          T.any(
            Packwerk::UnresolvedReference,
            Packwerk::Offense,
          )
        ]
      )
    end
    def call(file_path)
      return [UnknownFileTypeResult.new(file: file_path)] if parser_for(file_path).nil?

      @cache.with_cache(file_path) do
        node = parse_into_ast(file_path)

        return [] unless node

        references_from_ast(node, file_path)
      end
    rescue Parsers::ParseError => e
      [e.result]
    end

    private

    sig do
      params(node: Parser::AST::Node, file_path: String).returns(T::Array[UnresolvedReference])
    end
    def references_from_ast(node, file_path)
      references = []

      node_processor = @node_processor_factory.for(filename: file_path, node: node)
      node_visitor = Packwerk::NodeVisitor.new(node_processor: node_processor)
      node_visitor.visit(node, ancestors: [], result: references)

      references
    end

    def parse_into_ast(file_path)
      File.open(file_path, "r", nil, external_encoding: Encoding::UTF_8) do |file|
        parser_for(file_path).call(io: file, file_path: file_path)
      end
    end

    def parser_for(file_path)
      @parser_factory.for_path(file_path)
    end
  end
end
