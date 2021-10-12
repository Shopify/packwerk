# typed: true
# frozen_string_literal: true

module Packwerk
  # A reference from a file in one package to a constant that may be defined in a different package.
  Reference = Struct.new(:source_package, :relative_path, :constant, :source_location)
end
