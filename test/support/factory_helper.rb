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
      name: constant_name,
      location: "some/location.rb",
      package: destination_package,
      public: public_constant
    )
    Packwerk::Reference.new(source_package: source_package, relative_path: path, constant: constant,
source_location: source_location)
  end
end
