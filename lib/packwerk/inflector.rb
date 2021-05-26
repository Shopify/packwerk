# typed: true
# frozen_string_literal: true

require "active_support/inflector"

module Packwerk
  class Inflector
    class << self
      extend T::Sig

      def default
        @default ||= new(custom_inflector: Inflections::Custom.new)
      end

      sig { params(inflections_file: String).returns(::Packwerk::Inflector) }
      def from_file(inflections_file)
        new(custom_inflector: Inflections::Custom.new(inflections_file))
      end
    end

    extend T::Sig
    include ::ActiveSupport::Inflector # For #camelize, #classify, #pluralize, #singularize

    sig do
      params(
        custom_inflector: Inflections::Custom
      ).void
    end
    def initialize(custom_inflector:)
      @inflections = ::ActiveSupport::Inflector::Inflections.new

      Inflections::Default.apply_to(@inflections)
      custom_inflector.apply_to(@inflections)
    end

    def pluralize(word, count = nil)
      if count == 1
        singularize(word)
      else
        super(word)
      end
    end

    def inflections(_ = nil)
      @inflections
    end
  end
end
