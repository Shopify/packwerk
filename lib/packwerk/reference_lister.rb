# typed: strict
# frozen_string_literal: true

module Packwerk
  module ReferenceLister
    extend T::Sig
    extend T::Helpers

    interface!

    sig do
      params(reference: Packwerk::Reference, violation_type: ViolationType)
        .returns(T::Boolean)
        .abstract
    end
    def listed?(reference, violation_type:); end
  end
end
