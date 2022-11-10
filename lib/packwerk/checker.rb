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
        @checkers ||= T.let(@checkers, T.nilable(T::Array[Class]))
        @checkers ||= []
        @checkers << base
      end

      sig { returns(T::Array[Checker]) }
      def all
        T.unsafe(@checkers).map(&:new)
      end

      sig { params(violation_type: String).returns(Checker) }
      def find(violation_type)
        T.must(Checker.all.find { |c| c.violation_type == violation_type })
      end
    end

    sig { abstract.returns(String) }
    def violation_type; end

    sig { abstract.params(reference: Reference).returns(T::Boolean) }
    def invalid_reference?(reference); end

    sig { abstract.params(reference: Reference).returns(String) }
    def message(reference); end

    sig { params(reference: Reference).returns(Package) }
    def todo_file_for(reference)
      reference.source_package
    end
  end
end
