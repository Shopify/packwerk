# typed: true
# frozen_string_literal: true

module Packwerk
  # A partially qualified reference from a file in one package to a constant that may be defined in a different package.
  # Partially qualfiied means that we know how it's referred to in the file,
  # and we have enough context on that reference to figure out the fully qualified reference such that we
  # can produce a Reference in a separate pass.
  PartiallyQualifiedReference = Struct.new(:constant_name, :namespace_path, :relative_path, :source_location)
end
