# typed: true

module Packwerk
  class UnresolvedReference
    #: (constant_name: String, namespace_path: Array[String]?, relative_path: String, source_location: Node::Location?) -> void
    def initialize(
      constant_name:,
      namespace_path:,
      relative_path:,
      source_location:
    )
    end

    #: String
    attr_reader(:constant_name)

    #: Array[String]?
    attr_reader(:namespace_path)

    #: String
    attr_reader(:relative_path)

    #: Node::Location?
    attr_reader(:source_location)
  end
end
