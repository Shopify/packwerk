# typed: strict
# frozen_string_literal: true

module Packwerk
  # A reference from a file in one package to a constant that may be defined in a different package.
  class Reference < T::Struct
    const :source_package, T.nilable(Package)
    const :relative_path, String
    const :constant, ConstantDiscovery::ConstantContext
    const :source_location, Node::Location
  end
end
