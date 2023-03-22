# typed: strict
# frozen_string_literal: true

module Packwerk
  module Checker
    extend T::Sig
    extend T::Helpers

    abstract!

    class << self
      extend T::Sig

      sig { params(base: Class).void }
      def included(base)
        checkers << base
      end

      sig { returns(T::Array[Checker]) }
      def all
        load_defaults
        T.cast(checkers.map(&:new), T::Array[Checker])
      end

      sig { params(violation_type: String).returns(Checker) }
      def find(violation_type)
        checker_by_violation_type(violation_type)
      end

      private

      sig { void }
      def load_defaults
        require("packwerk/reference_checking/checkers/dependency_checker")
      end

      sig { returns(T::Array[Class]) }
      def checkers
        @checkers ||= T.let([], T.nilable(T::Array[Class]))
      end

      sig { params(name: String).returns(Checker) }
      def checker_by_violation_type(name)
        @checker_by_violation_type ||= T.let(Checker.all.to_h do |checker|
                                               [checker.violation_type, checker]
                                             end, T.nilable(T::Hash[String, Checker]))
        @checker_by_violation_type.fetch(name)
      end
    end

    sig { abstract.returns(String) }
    def violation_type; end

    sig { abstract.params(listed_offense: ReferenceOffense).returns(T::Boolean) }
    def strict_mode_violation?(listed_offense); end

    sig { abstract.params(reference: Reference).returns(T::Boolean) }
    def invalid_reference?(reference); end

    sig { abstract.params(reference: Reference).returns(String) }
    def message(reference); end
  end
end
