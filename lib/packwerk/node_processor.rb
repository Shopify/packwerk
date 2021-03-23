# typed: true
# frozen_string_literal: true

require "packwerk/node"
require "packwerk/offense"
require "packwerk/checker"
require "packwerk/reference_lister"

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

    def call(node, ancestors:)
      if Node.method_call?(node) || Node.constant?(node)
        reference = @reference_extractor.reference_from_node(node, ancestors: ancestors, file_path: @filename)
        check_reference(reference, node) if reference
      end
    end

    private

    def check_reference(reference, node)
      @checkers.each_with_object([]) do |checker, violations|
        next unless checker.invalid_reference?(reference, @reference_lister)
        constant = reference.constant
        message = checker.message_for(reference)

        offense = Packwerk::Offense.new(
          location: Node.location(node),
          file: reference.relative_path,
          reference: reference,
          violation_type: checker.violation_type,
          message: <<~EOS
            #{message}
            Inference details: this is a reference to #{constant.name} which seems to be defined in #{constant.location}.
            To receive help interpreting or resolving this error message, see: https://github.com/Shopify/packwerk/blob/main/TROUBLESHOOT.md#Troubleshooting-violations
          EOS
        )
        violations << offense
      end
    end
  end
end
