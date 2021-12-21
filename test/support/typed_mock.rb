# typed: true
# frozen_string_literal: true

module TypedMock
  extend T::Sig
  include(::Mocha::API)

  sig { returns(Mocha::Mock) }
  def typed_mock
    m = mock
    m.stubs(:is_a?).returns(true)
    m
  end
end
