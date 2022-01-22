# typed: strict
# frozen_string_literal: true

module Packwerk
  module ReferenceChecking
    module Checkers
      module Checker
        extend T::Sig
        extend T::Helpers

        interface!

        sig { returns(ViolationType).abstract }
        def violation_type; end

        sig { params(reference: Reference).returns(T::Boolean).abstract }
        def invalid_reference?(reference); end
      end
    end
  end
end
