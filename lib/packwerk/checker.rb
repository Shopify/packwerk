# typed: strict
# frozen_string_literal: true

module Packwerk
  module Checker
    extend T::Sig
    extend T::Helpers

    abstract!

    class << self
      extend T::Sig

      #: (Class[top] base) -> void
      def included(base)
        checkers << base
      end

      #: -> Array[Checker]
      def all
        load_defaults
        T.cast(checkers.map(&:new), T::Array[Checker])
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
        @checkers ||= T.let([], T.nilable(T::Array[T::Class[T.anything]]))
      end

      #: (String name) -> Checker
      def checker_by_violation_type(name)
        @checker_by_violation_type ||= T.let(Checker.all.to_h do |checker|
                                               [checker.violation_type, checker]
                                             end, T.nilable(T::Hash[String, Checker]))
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
