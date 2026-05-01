# typed: strict
# frozen_string_literal: true

require "parser"

module Packwerk
  class FileProcessor
    class UnknownFileTypeResult < Offense
      #: (file: String) -> void
      def initialize(file:)
        super(file: file, message: "unknown file type")
      end
    end

    #: (node_processor_factory: NodeProcessorFactory, cache: Cache, ?parser_factory: Parsers::Factory?) -> void
    def initialize(node_processor_factory:, cache:, parser_factory: nil)
      @node_processor_factory = node_processor_factory
      @cache = cache
      @parser_factory = parser_factory || Packwerk::Parsers::Factory.instance #: Parsers::Factory
    end

    class ProcessedFile < T::Struct
      const :unresolved_references, T::Array[UnresolvedReference], default: []
      const :offenses, T::Array[Offense], default: []
    end

    #: (String relative_file) -> ProcessedFile
    def call(relative_file)
      parser = parser_for(relative_file)
      if parser.nil?
        return ProcessedFile.new(offenses: [UnknownFileTypeResult.new(file: relative_file)])
      end

      unresolved_references = @cache.with_cache(relative_file) do
        node = parse_into_ast(relative_file, parser)
        return ProcessedFile.new unless node

        references_from_ast(node, relative_file)
      end

      ProcessedFile.new(unresolved_references: unresolved_references)
    rescue Parsers::ParseError => e
      ProcessedFile.new(offenses: [e.result])
    rescue StandardError => e
      message = <<~MSG
        Packwerk encountered an internal error.
        For now, you can add this file to `packwerk.yml` `exclude` list.
        Please file an issue and include this error message and stacktrace:

        #{e.message} #{e.backtrace&.join("\n")}"
      MSG

      offense = Parsers::ParseResult.new(file: relative_file, message: message)
      ProcessedFile.new(offenses: [offense])
    end

    private

    #: (Parser::AST::Node node, String relative_file) -> Array[UnresolvedReference]
    def references_from_ast(node, relative_file)
      references = []

      node_processor = @node_processor_factory.for(relative_file: relative_file, node: node)
      node_visitor = NodeVisitor.new(node_processor: node_processor)
      node_visitor.visit(node, ancestors: [], result: references)

      references
    end

    #: (String relative_file, Parsers::ParserInterface parser) -> untyped
    def parse_into_ast(relative_file, parser)
      File.open(relative_file, "r", nil, external_encoding: Encoding::UTF_8) do |file|
        parser.call(io: file, file_path: relative_file)
      end
    end

    #: (String file_path) -> Parsers::ParserInterface?
    def parser_for(file_path)
      @parser_factory.for_path(file_path)
    end
  end

  private_constant :FileProcessor
end
