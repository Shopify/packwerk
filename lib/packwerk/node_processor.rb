# typed: true
# frozen_string_literal: true

require "packwerk/node"
require "packwerk/offense"
require "packwerk/checker"

module Packwerk
  class NodeProcessor
    extend T::Sig

    sig do
      params(
        reference_extractor: ReferenceExtractor,
        filename: String,
        checkers: T::Array[Checker]
      ).void
    end
    def initialize(reference_extractor:, filename:, checkers:)
      @reference_extractor = reference_extractor
      @filename = filename
      @checkers = checkers
    end

    sig { params(node: Parser::AST::Node, ancestors: T::Array[Parser::AST::Node]).returns(T.nilable(Offense)) }
    def call(node, ancestors)
      if Node.method_call?(node) || Node.constant?(node)
        reference = @reference_extractor.reference_from_node(node, ancestors: ancestors, file_path: @filename)
        check_reference(reference, node) if reference
      end
    end

    private

    def check_reference(reference, node)
      @checkers.each_with_object([]) do |checker, violations|
        next unless checker.invalid_reference?(reference)
        offense = Packwerk::ReferenceOffense.new(
          location: Node.location(node),
          reference: reference,
          violation_type: checker.violation_type
        )
        violations << offense
      end
    end
  end
end
