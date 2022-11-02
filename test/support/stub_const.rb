# typed: true
# frozen_string_literal: true

module StubConst
  def with_stubbed_const(klass, const, val)
    original_value = klass.const_get(const) # rubocop:disable Sorbet/ConstantsFromStrings
    klass.const_set(const, val)
    yield
  ensure
    klass.const_set(const, original_value)
  end
end
