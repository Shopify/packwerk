# typed: ignore
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class ConstantDiscoveryTest < Minitest::Test
    def setup
      @root_path = "test/fixtures/skeleton/"
      load_paths =
        Dir.glob(File.join(@root_path, "components/*/{app,test}/*{/concerns,}"))
          .map { |p| Pathname.new(p).relative_path_from(@root_path).to_s }

      @discovery = ConstantDiscovery.new(
        constant_resolver: ConstantResolver.new(root_path: @root_path, load_paths: load_paths),
        packages: PackageSet.load_all_from(@root_path)
      )
      super
    end

    test "discovers simple constant" do
      constant = @discovery.context_for("Order")
      assert_equal("::Order", constant.name)
      assert_equal("components/sales/app/models/order.rb", constant.location)
      assert_equal("components/sales", constant.package.name)
      assert_equal(false, constant.public?)
    end

    test "recognizes constants as public" do
      constant = @discovery.context_for("Sales::RecordNewOrder")
      assert_equal("::Sales::RecordNewOrder", constant.name)
      assert_equal("components/sales/app/public/sales/record_new_order.rb", constant.location)
      assert_equal("components/sales", constant.package.name)
      assert_equal(true, constant.public?)
    end

    test "raises with helpful message if there is a constant resolver error" do
      constant_resolver = stub
      constant_resolver.stubs(:resolve).raises(ConstantResolver::Error, "initial error message")
      discovery = ConstantDiscovery.new(
        constant_resolver: constant_resolver,
        packages: PackageSet.load_all_from(@root_path)
      )

      error = assert_raises(ConstantResolver::Error) do
        discovery.context_for("Sales::RecordNewOrder")
      end

      assert_equal(error.message, "initial error message\n Make sure autoload paths are added to the config file.")
    end
  end
end
