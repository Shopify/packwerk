# typed: true
# frozen_string_literal: true

module Packwerk
  class ZeitwerkOffense < Offense
    attr_reader :constant

    def initialize(constant:, file:, message:, location:)
      super(file: file, message: message, location: location)
      @constant = constant
    end
  end
end
