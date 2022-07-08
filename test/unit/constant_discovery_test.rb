# typed: true
# frozen_string_literal: true

require "test_helper"

module Business
end

module Packwerk
  class ConstantDiscoveryTest < Minitest::Test
    include TypedMock

    def setup
      @root_path = "test/fixtures/skeleton/"
      load_paths =
        Dir.glob(File.join(@root_path, "components/*/{app,test}/*{/concerns,}"))
          .map { |p| Pathname.new(p).relative_path_from(@root_path).to_s }
          .each_with_object({}) { |p, h| h[p] = Object }

      load_paths["components/sales/app/internal"] = Business

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

    test "discovers constant in root dir with non-default namespace" do
      constant = @discovery.context_for("Business::Special")
      assert_equal("::Business::Special", constant.name)
      assert_equal("components/sales/app/internal/special.rb", constant.location)
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
      constant_resolver = typed_mock
      constant_resolver.stubs(:resolve).raises(ConstantResolver::Error, "initial error message")
      discovery = ConstantDiscovery.new(
        constant_resolver: constant_resolver,
        packages: PackageSet.load_all_from(@root_path)
      )

      error = assert_raises(ConstantResolver::Error) do
        discovery.context_for("Sales::RecordNewOrder")
      end

      assert_equal(error.message, "initial error message")
    end
  end
end
