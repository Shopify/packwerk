# typed: strict
# frozen_string_literal: true

module Packwerk
  # @interface
  module OutputStyle
    # @abstract
    #: -> String
    def reset = raise NotImplementedError, "Abstract method called"

    # @abstract
    #: -> String
    def filename = raise NotImplementedError, "Abstract method called"

    # @abstract
    #: -> String
    def error = raise NotImplementedError, "Abstract method called"
  end
end
