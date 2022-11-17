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
      params(absolute_file: String).returns(
        T::Array[
          T.any(
            Packwerk::UnresolvedReference,
            Packwerk::Offense,
          )
        ]
      )
    end
    def call(absolute_file)
      parser = parser_for(absolute_file)
      return [UnknownFileTypeResult.new(file: absolute_file)] if T.unsafe(parser).nil?

      @cache.with_cache(absolute_file) do
        node = parse_into_ast(absolute_file, T.must(parser))
        return [] unless node

        references_from_ast(node, absolute_file)
      end
    rescue Parsers::ParseError => e
      [e.result]
    end

    private

    sig do
      params(node: ::Parser::AST::Node, absolute_file: String).returns(T::Array[UnresolvedReference])
    end
    def references_from_ast(node, absolute_file)
      references = []

      node_processor = @node_processor_factory.for(absolute_file: absolute_file, node: node)
      node_visitor = Packwerk::NodeVisitor.new(node_processor: node_processor)
      node_visitor.visit(node, ancestors: [], result: references)

      references
    end

    sig { params(absolute_file: String, parser: Packwerk::Parser).returns(T.untyped) }
    def parse_into_ast(absolute_file, parser)
      File.open(absolute_file, "r", nil, external_encoding: Encoding::UTF_8) do |file|
        parser.call(io: file, file_path: absolute_file)
      end
    end

    sig { params(file_path: String).returns(T.nilable(Packwerk::Parser)) }
    def parser_for(file_path)
      @parser_factory.for_path(file_path)
    end
  end
end
