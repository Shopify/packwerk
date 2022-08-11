# typed: true
# frozen_string_literal: true

module TestAssertions
  class << self
    def included(klass)
      klass.alias_method(:assert_not_nil, :refute_nil)
    end
  end
end
