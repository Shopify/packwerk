# typed: strict
# frozen_string_literal: true

module Packwerk
  module OutputStyle
    extend T::Sig
    extend T::Helpers

    interface!

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
