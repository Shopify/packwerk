# typed: false
# frozen_string_literal: true

module TestAssertions
  def self.included(klass)
    klass.alias_method(:assert_not_nil, :refute_nil)
  end
end
