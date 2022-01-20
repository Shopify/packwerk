# typed: strict
# frozen_string_literal: true

module TypedMock
  extend T::Sig
  include(::Mocha::API)

  sig { returns(T.untyped) }
  def typed_mock
    m = mock
    m.stubs(:is_a?).returns(true)
    m
  end
end
