# typed: true
# frozen_string_literal: true

require "packwerk/offense"
require "sorbet-runtime"

module Packwerk
  class ReferenceOffense < Offense
    extend T::Sig
    extend T::Helpers

    attr_reader :reference, :violation_type

    sig do
      params(
        file: String, message: String,
        reference: Packwerk::Reference,
        violation_type: Packwerk::ViolationType,
        location: T.nilable(Node::Location)
      )
        .void
    end
    def initialize(file:, message:, reference:, violation_type:, location: nil)
      super(file: file, message: message, location: location)
      @reference = reference
      @violation_type = violation_type
    end
  end
end
