# typed: true

module Packwerk
  class Reference
    sig do
      params(
        package: Package,
        relative_path: String,
        constant: Private::ConstantDiscovery::ConstantContext,
        source_location: T.nilable(Private::Node::Location),
      ).void
    end
    def initialize(
      package:,
      relative_path:,
      constant:,
      source_location:
    )
    end

    sig { returns(Package) }
    attr_reader(:package)

    sig { returns(T.nilable(String)) }
    attr_reader(:relative_path)

    sig { returns(Private::ConstantDiscovery::ConstantContext) }
    attr_reader(:constant)

    sig { returns(T.nilable(Private::Node::Location)) }
    attr_reader(:source_location)
  end
end
