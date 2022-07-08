# typed: true
# frozen_string_literal: true

module FactoryHelper
  def build_reference(
    source_package: Packwerk::Package.new(name: "components/source", config: {}),
    destination_package: Packwerk::Package.new(name: "components/destination", config: {}),
    path: "some/path.rb",
    constant_name: "::SomeName",
    public_constant: false,
    source_location: Packwerk::Node::Location.new(2, 12)
  )
    constant = Packwerk::ConstantDiscovery::ConstantContext.new(
      constant_name,
      "some/location.rb",
      destination_package,
      public_constant
    )
    Packwerk::Reference.new(source_package, path, constant, source_location)
  end
end
