# typed: true
# frozen_string_literal: true

module Packwerk
  class ReferenceOffense < Offense
    extend T::Sig
    extend T::Helpers

    attr_reader :reference, :violation_type

    sig do
      params(
        reference: Packwerk::Reference,
        violation_type: Packwerk::ViolationType,
        location: T.nilable(Node::Location)
      )
        .void
    end
    def initialize(reference:, violation_type:, location: nil)
      super(file: reference.relative_path, message: build_message(reference, violation_type), location: location)
      @reference = reference
      @violation_type = violation_type
    end

    private

    def build_message(reference, violation_type)
      violation_message = case violation_type
      when ViolationType::Privacy
        source_desc = reference.source_package ? "'#{reference.source_package}'" : "here"
        "Privacy violation: '#{reference.constant.name}' is private to '#{reference.constant.package}' but " \
        "referenced from #{source_desc}.\n" \
        "Is there a public entrypoint in '#{reference.constant.package.public_path}' that you can use instead?"
      when ViolationType::Dependency
        "Dependency violation: #{reference.constant.name} belongs to '#{reference.constant.package}', but " \
        "'#{reference.source_package}' does not specify a dependency on " \
        "'#{reference.constant.package}'.\n" \
        "Are we missing an abstraction?\n" \
        "Is the code making the reference, and the referenced constant, in the right packages?\n"
      end

      <<~EOS
        #{violation_message}
        Inference details: this is a reference to #{reference.constant.name} which seems to be defined in #{reference.constant.location}.
        To receive help interpreting or resolving this error message, see: https://github.com/Shopify/packwerk/blob/main/TROUBLESHOOT.md#Troubleshooting-violations
      EOS
    end
  end
end
