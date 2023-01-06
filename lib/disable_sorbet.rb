# typed: true
# frozen_string_literal: true

require "sorbet-runtime"

T::Configuration.default_checked_level = :never

T.singleton_class.prepend(
  Module.new do
    def cast(value, type, checked: true)
      value
    end

    def let(value, type, checked: true)
      value
    end

    def must(arg)
      arg
    end

    def absurd(value)
      value
    end

    def bind(value, type, checked: true)
      value
    end
  end
)
