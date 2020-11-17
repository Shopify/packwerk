# typed: true
# frozen_string_literal: true

require "packwerk/cache_deprecated_references"

module Packwerk
  class UpdatingDeprecatedReferences < CacheDeprecatedReferences
    def dump_deprecated_references_files
      @deprecated_references.each do |_, deprecated_references_file|
        deprecated_references_file.dump
      end
    end
  end
end
