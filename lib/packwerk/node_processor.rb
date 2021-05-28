# typed: true
# frozen_string_literal: true

module Packwerk
  class NodeProcessor
    extend T::Sig

    sig do
      params(
        reference_extractor: ReferenceExtractor,
        reference_lister: ReferenceLister,
        filename: String,
        checkers: T::Array[Checker]
      ).void
    end
    def initialize(reference_extractor:, reference_lister:, filename:, checkers:)
      @reference_extractor = reference_extractor
      @reference_lister = reference_lister
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
      return nil unless (failing_checker = failed_check(reference))

      Packwerk::ReferenceOffense.new(
        location: Node.location(node),
        reference: reference,
        violation_type: failing_checker.violation_type
      )
    end

    def failed_check(reference)
      @checkers.find do |checker|
        checker.invalid_reference?(reference)
      end
    end
  end
end
