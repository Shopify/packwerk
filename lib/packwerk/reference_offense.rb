# typed: strict
# frozen_string_literal: true

module Packwerk
  # An offense related to a {Packwerk::Reference}.
  class ReferenceOffense < Offense
    #: Reference
    attr_reader :reference

    #: String
    attr_reader :violation_type

    #: (reference: Packwerk::Reference, violation_type: String, message: String, ?location: Node::Location?) -> void
    def initialize(reference:, violation_type:, message:, location: nil)
      file = reference.relative_path #: as !nil
      super(file: file, message: message, location: location)
      @reference = reference
      @violation_type = violation_type
    end
  end
end
