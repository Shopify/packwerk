# typed: strict
# frozen_string_literal: true

module TypedMock
  include(::Mocha::API)

  #: (**untyped params) -> untyped
  def typed_mock(**params)
    m = mock(params)
    m.stubs(:is_a?).returns(true)
    m
  end
end
