# typed: strict
# frozen_string_literal: true

require "ast/node"

module Packwerk
  class FileProcessor
    extend T::Sig

    class UnknownFileTypeResult < Offense
      extend T::Sig

      sig { params(file: String).void }
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
      @parser_factory = T.let(parser_factory || Packwerk::Parsers::Factory.instance, Parsers::Factory)
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
      parser = parser_for(file_path)
      return [UnknownFileTypeResult.new(file: file_path)] if T.unsafe(parser).nil?

      @cache.with_cache(file_path) do
        node = parse_into_ast(file_path, T.must(parser))
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

    sig { params(file_path: String, parser: Parsers::ParserInterface).returns(T.untyped) }
    def parse_into_ast(file_path, parser)
      File.open(file_path, "r", nil, external_encoding: Encoding::UTF_8) do |file|
        parser.call(io: file, file_path: file_path)
      end
    end

    sig { params(file_path: String).returns(T.nilable(Parsers::ParserInterface)) }
    def parser_for(file_path)
      @parser_factory.for_path(file_path)
    end
  end
end
