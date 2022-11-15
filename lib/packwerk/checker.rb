# typed: strict
# frozen_string_literal: true

module Packwerk
  module Checker
    extend T::Sig
    extend T::Helpers

    class TodoLocation < T::Enum
      enums do
        PackageReferencingConstant = new
        PackageDefiningConstant = new
      end
    end

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
        checker_by_violation_type(violation_type)
      end

      private

      sig { params(name: String).returns(Checker) }
      def checker_by_violation_type(name)
        @checker_by_violation_type ||= T.let(@checker_by_violation_type, T.nilable(T::Hash[String, T.nilable(Checker)]))
        @checker_by_violation_type ||= Checker.all.map { |c| [c.violation_type, c] }.to_h
        T.must(@checker_by_violation_type[name])
      end
    end

    sig { abstract.returns(String) }
    def violation_type; end

    sig { abstract.params(reference: Reference).returns(T::Boolean) }
    def invalid_reference?(reference); end

    sig { abstract.params(reference: Reference).returns(String) }
    def message(reference); end

    sig { returns(TodoLocation) }
    def todo_location
      TodoLocation::PackageReferencingConstant
    end

    sig { params(reference: Reference).returns(Package) }
    def todo_file_for(reference)
      location = todo_location
      case location
      when TodoLocation::PackageDefiningConstant
        reference.constant.package
      when TodoLocation::PackageReferencingConstant
        reference.source_package
      else
        T.absurd(location)
      end
    end
  end
end
