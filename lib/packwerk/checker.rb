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
    end

    sig { abstract.returns(String) }
    def violation_type; end

    sig { abstract.params(reference: Reference).returns(T::Boolean) }
    def invalid_reference?(reference); end

    sig { abstract.params(reference: Reference).returns(String) }
    def message(reference); end
  end
end
