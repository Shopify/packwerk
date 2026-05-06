# typed: true

module Packwerk
  class Reference
    #: (package: Package, relative_path: String, constant: ConstantContext, source_location: Node::Location?) -> void
    def initialize(
      package:,
      relative_path:,
      constant:,
      source_location:
    )
    end

    #: Package
    attr_reader(:package)

    #: String?
    attr_reader(:relative_path)

    #: ConstantContext
    attr_reader(:constant)

    #: Node::Location?
    attr_reader(:source_location)
  end
end
