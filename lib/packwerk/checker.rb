# typed: strict
# frozen_string_literal: true

module Packwerk
  # @abstract
  module Checker
    class << self
      #: (Class[top] base) -> void
      def included(base)
        checkers << base
      end

      #: -> Array[Checker]
      def all
        load_defaults
        checkers.map(&:new) #: as Array[Checker]
      end

      #: (String violation_type) -> Checker
      def find(violation_type)
        checker_by_violation_type(violation_type)
      end

      private

      #: -> void
      def load_defaults
        require("packwerk/reference_checking/checkers/dependency_checker")
      end

      #: -> Array[Class[top]]
      def checkers
        @checkers ||= [] #: Array[Class[top]]?
      end

      #: (String name) -> Checker
      def checker_by_violation_type(name)
        @checker_by_violation_type ||= Checker.all.to_h do |checker|
          [checker.violation_type, checker]
        end #: Hash[String, Checker]?
        @checker_by_violation_type.fetch(name)
      end
    end

    # @abstract
    #: -> String
    def violation_type = raise NotImplementedError, "Abstract method called"

    # @abstract
    #: (ReferenceOffense offense) -> bool
    def strict_mode_violation?(offense) = raise NotImplementedError, "Abstract method called"

    # @abstract
    #: (Reference reference) -> bool
    def invalid_reference?(reference) = raise NotImplementedError, "Abstract method called"

    # @abstract
    #: (Reference reference) -> String
    def message(reference) = raise NotImplementedError, "Abstract method called"
  end
end
