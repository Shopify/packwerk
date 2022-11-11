# typed: true

module Packwerk
  class UnresolvedReference
    sig do
      params(
        constant_name: String,
        namespace_path: T.nilable(T::Array[String]),
        relative_path: String,
        source_location: T.nilable(Node::Location),
      ).void
    end
    def initialize(
      constant_name:,
      namespace_path:,
      relative_path:,
      source_location:
    )
    end

    sig { returns(String) }
    attr_reader(:constant_name)

    sig { returns(T.nilable(T::Array[String])) }
    attr_reader(:namespace_path)

    sig { returns(String) }
    attr_reader(:relative_path)

    sig { returns(T.nilable(Node::Location)) }
    attr_reader(:source_location)
  end
end
