# typed: strict
# frozen_string_literal: true

module Packwerk
  # This is a test module to see if `private_constant` will attempt to load the class
  module TestThing
    raise "Uh oh, we are loading!"
  end
end
