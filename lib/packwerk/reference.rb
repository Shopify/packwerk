# typed: strict
# frozen_string_literal: true

module Packwerk
  # A reference from a file in one package to a constant that may be defined in a different package.
  class Reference
    extend T::Sig

    sig { returns(T.nilable(Package)) }
    attr_reader :source_package
    sig { returns(String) }
    attr_reader :relative_path
    sig { returns(ConstantDiscovery::ConstantContext) }
    attr_reader :constant
    sig { returns(Node::Location) }
    attr_reader :source_location

    sig do
      params(
        source_package: T.nilable(Package),
        relative_path: String,
        constant: ConstantDiscovery::ConstantContext,
        source_location: Node::Location,
      ).void
    end
    def initialize(source_package:, relative_path:, constant:, source_location:)
      @source_package = source_package
      @relative_path = relative_path
      @constant = constant
      @source_location = source_location
    end
  end
end
