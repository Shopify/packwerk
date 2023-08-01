# typed: true
# frozen_string_literal: true

require "yaml"

module Packwerk
  module Inflections
    class Custom
      SUPPORTED_INFLECTION_METHODS = ["acronym", "human", "irregular", "plural", "singular", "uncountable"]

      attr_accessor :inflections

      def initialize(custom_inflection_file = nil)
        if custom_inflection_file && File.exist?(custom_inflection_file)
          @inflections = YAML.safe_load(custom_inflection_file, permitted_classes: [Regexp]) || {}

          invalid_inflections = @inflections.keys - SUPPORTED_INFLECTION_METHODS
          raise ArgumentError, "Unsupported inflection types: #{invalid_inflections}" if invalid_inflections.any?
        else
          @inflections = []
        end
      end

      def apply_to(inflections_object)
        @inflections.each do |inflection_type, inflections|
          inflections.each do |inflection|
            inflections_object.public_send(inflection_type, *Array(inflection))
          end
        end
      end
    end
  end
end
