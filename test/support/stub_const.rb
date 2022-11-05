# typed: strict
# frozen_string_literal: true

module StubConst
  extend T::Sig

  sig do
    params(
      mod: Module,
      const: T.any(Symbol, String),
      value: Object,
      block: T.proc.void
    ).void
  end
  def with_stubbed_const(mod, const, value, &block)
    original_value = mod.const_get(const) # rubocop:disable Sorbet/ConstantsFromStrings

    Kernel.silence_warnings do
      mod.const_set(const, value)
      yield
    ensure
      mod.const_set(const, original_value)
    end
  end
end
