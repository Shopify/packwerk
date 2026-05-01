# typed: strict
# frozen_string_literal: true

module Packwerk
  module ReferenceChecking
    class ReferenceChecker
      #: (Array[Checker] checkers) -> void
      def initialize(checkers)
        @checkers = checkers
      end

      #: (Reference reference) -> Array[Packwerk::Offense]
      def call(reference)
        @checkers.each_with_object([]) do |checker, violations|
          next unless checker.invalid_reference?(reference)

          offense = Packwerk::ReferenceOffense.new(
            location: reference.source_location,
            reference: reference,
            violation_type: checker.violation_type,
            message: checker.message(reference)
          )
          violations << offense
        end
      end
    end
  end
end
