# typed: true
# frozen_string_literal: true

require "active_support/inflector"
require "packwerk/inflections/default"
require "packwerk/inflections/custom"

module Packwerk
  class Inflector
    class << self
      def default
        @default ||= new
      end
    end

    # For #camelize, #classify, #pluralize, #singularize
    include ::ActiveSupport::Inflector

    def initialize(custom_inflection_file: nil)
      @inflections = ::ActiveSupport::Inflector::Inflections.new

      Inflections::Default.apply_to(@inflections)

      Inflections::Custom.new(custom_inflection_file).apply_to(@inflections)
    end

    def pluralize(word, count = nil)
      if count == 1
        singularize(word)
      else
        super(word)
      end
    end

    private

    def inflections(_ = nil)
      @inflections
    end
  end
end
