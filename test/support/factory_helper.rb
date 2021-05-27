# typed: false
# frozen_string_literal: true

module FactoryHelper
  def build_reference(
    source_package: Packwerk::Package.new(name: "components/source", config: {}),
    destination_package: Packwerk::Package.new(name: "components/destination", config: {}),
    path: "some/path.rb",
    constant_name: "::SomeName",
    public_constant: false
  )
    constant = Packwerk::ConstantDiscovery::ConstantContext.new(
      constant_name,
      "some/location.rb",
      destination_package,
      public_constant
    )
    Packwerk::Reference.new(source_package, path, constant)
  end
end
