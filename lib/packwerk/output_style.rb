# typed: strict
# frozen_string_literal: true

module Packwerk
  # @interface
  module OutputStyle
    # @abstract
    #: -> String
    def reset = super

    # @abstract
    #: -> String
    def filename = super

    # @abstract
    #: -> String
    def error = super
  end
end
