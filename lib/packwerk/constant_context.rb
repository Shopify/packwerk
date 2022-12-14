# typed: true
# frozen_string_literal: true

require "constant_resolver"

module Packwerk
  extend T::Sig

  ConstantContext = Struct.new(:name, :location, :package)
end
