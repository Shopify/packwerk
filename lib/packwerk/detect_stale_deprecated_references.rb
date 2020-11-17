# typed: strict
# frozen_string_literal: true

require "packwerk/cache_deprecated_references"

module Packwerk
  class DetectStaleDeprecatedReferences < CacheDeprecatedReferences
    extend T::Sig
    sig { returns(T::Boolean) }
    def stale_violations?
      @deprecated_references.values.any?(&:stale_violations?)
    end
  end
end
