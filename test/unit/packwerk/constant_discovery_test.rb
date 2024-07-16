# typed: true
# frozen_string_literal: true

require "test_helper"

module Business
end

module Packwerk
  class ConstantDiscoveryTest < Minitest::Test
    include TypedMock

    test "discovers simple constant" do
      constant = discovery.context_for("Order")
      assert_equal("::Order", constant.name)
      assert_equal("components/sales/app/models/order.rb", constant.location)
      assert_equal("components/sales", constant.package.name)
    end

    test "discovers constant in root dir with non-default namespace" do
      with_non_default_namespace = discovery do |load_paths|
        load_paths["components/sales/app/internal"] = Business
      end

      constant = with_non_default_namespace.context_for("Business::Special")
      assert_equal("::Business::Special", constant.name)
      assert_equal("components/sales/app/internal/special.rb", constant.location)
      assert_equal("components/sales", constant.package.name)
    end

    test "raises with helpful message if there is a constant resolver error" do
      constant_resolver = typed_mock
      constant_resolver.stubs(:resolve).raises(ConstantResolver::Error, "initial error message")
      discovery = ConstantDiscovery.new(
        constant_resolver: constant_resolver,
        packages: PackageSet.load_all_from("test/fixtures/skeleton/")
      )

      error = assert_raises(ConstantResolver::Error) do
        discovery.context_for("Sales::RecordNewOrder")
      end

      assert_equal(error.message, "initial error message")
    end

    test "raises when validating constants and load paths contain no ruby files" do
      with_no_ruby_files = discovery(&:clear)

      error = assert_raises(ConstantResolver::Error) do
        with_no_ruby_files.validate_constants
      end

      assert_match(/Could not find any ruby files/, error.message)
    end

    test "raises when validating constants that include an ambiguous reference" do
      with_ambiguous_ref = discovery("test/fixtures/ambiguous/")

      error = assert_raises(ConstantResolver::Error) do
        with_ambiguous_ref.validate_constants
      end

      assert_match(/Ambiguous constant definition/, error.message)
    end

    private

    def discovery(root_path = "test/fixtures/skeleton/")
      load_paths =
        Dir.glob(File.join(root_path, "components/*/{app,test}/*{/concerns,}"))
          .map { |p| Pathname.new(p).relative_path_from(root_path).to_s }
          .each_with_object({}) { |p, h| h[p] = Object }

      yield(load_paths) if block_given?

      ConstantDiscovery.for(
        PackageSet.load_all_from(root_path),
        root_path:  root_path,
        load_paths: load_paths
      )
    end
  end
end
