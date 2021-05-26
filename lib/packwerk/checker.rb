# typed: true
# frozen_string_literal: true

module Packwerk
  module Checker
    extend T::Sig
    extend T::Helpers

    interface!

    sig { returns(ViolationType).abstract }
    def violation_type; end

    sig { params(reference: Reference, reference_lister: ReferenceLister).returns(T::Boolean).abstract }
    def invalid_reference?(reference, reference_lister); end
  end
end
