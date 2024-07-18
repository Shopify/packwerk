# typed: true
# frozen_string_literal: true

require "test_helper"

module Business
end

module Packwerk
  class ConstantDiscoveryTest < Minitest::Test
    include RailsApplicationFixtureHelper

    setup do
      setup_application_fixture
    end

    teardown do
      teardown_application_fixture
    end

    test "discovers simple constant" do
      use_template(:skeleton)
      constant = discovery.context_for("Order")
      assert_equal("::Order", constant.name)
      assert_equal("components/sales/app/models/order.rb", constant.location)
      assert_equal("components/sales", constant.package.name)
    end

    test "does not discover constant with invalid casing" do
      use_template(:skeleton)
      constant = discovery.context_for("ORDER")
      assert_nil(constant)
    end

    test "discovers nested constant" do
      use_template(:skeleton)
      constant = discovery.context_for("Sales::Order")
      assert_equal("::Sales::Order", constant.name)
      assert_equal("components/sales/app/models/sales/order.rb", constant.location)
      assert_equal("components/sales", constant.package.name)

      constant = discovery.context_for("HasTimeline")
      assert_equal("::HasTimeline", constant.name)
      assert_equal("components/timeline/app/models/concerns/has_timeline.rb", constant.location)
      assert_equal("components/timeline", constant.package.name)
    end

    test "discovers constant that is fully qualified but does not have its own file" do
      use_template(:skeleton)
      constant = discovery.context_for("Sales::Errors::SomethingWentWrong")
      assert_equal("::Sales::Errors::SomethingWentWrong", constant.name)
      assert_equal("components/sales/app/public/sales/errors.rb", constant.location)
      assert_equal("components/sales", constant.package.name)
    end

    test "discovers constant that is partially qualified inferring their full qualification" do
      use_template(:skeleton)
      constant = discovery.context_for(
        "Errors",
        current_namespace_path: ["Sales", "SomeEntryPoint"]
      )
      assert_equal("::Sales::Errors", constant.name)
      assert_equal("components/sales/app/public/sales/errors.rb", constant.location)
      assert_equal("components/sales", constant.package.name)
    end

    test "discovers constant that is both partially qualified and do not have its own file" do
      use_template(:skeleton)
      constant = discovery.context_for(
        "Errors::SomethingWentWrong",
        current_namespace_path: ["Sales", "SomeEntrypoint"],
      )
      assert_equal("::Sales::Errors::SomethingWentWrong", constant.name)
      assert_equal("components/sales/app/public/sales/errors.rb", constant.location)
      assert_equal("components/sales", constant.package.name)
    end

    test "discovers constant that is partially qualified and has a common name" do
      use_template(:skeleton)
      constant = discovery.context_for("Order", current_namespace_path: ["Sales", "Order"])
      assert_equal("::Sales::Order", constant.name)
      assert_equal("components/sales/app/models/sales/order.rb", constant.location)
      assert_equal("components/sales", constant.package.name)
    end

    test "discovers constant in root dir with non-default namespace" do
      use_template(:skeleton)
      with_non_default_namespace = discovery do |loader|
        loader.push_dir(*to_app_paths("components/sales/app/internal"), namespace: Business)
      end

      constant = with_non_default_namespace.context_for("Business::Special")
      assert_equal("::Business::Special", constant.name)
      assert_equal("components/sales/app/internal/special.rb", constant.location)
      assert_equal("components/sales", constant.package.name)
    end

    test "discovers constant that is explicitly top level" do
      use_template(:skeleton)
      constant = discovery.context_for("::Order")
      assert_equal("::Order", constant.name)
      assert_equal("components/sales/app/models/order.rb", constant.location)
      assert_equal("components/sales", constant.package.name)
    end

    test "respects top level prefix when discovering constants" do
      use_template(:skeleton)
      constant = discovery.context_for("Order", current_namespace_path: ["Sales"])
      assert_equal("::Sales::Order", constant.name)
      assert_equal("components/sales/app/models/sales/order.rb", constant.location)
      assert_equal("components/sales", constant.package.name)

      constant = discovery.context_for("::Order", current_namespace_path: ["Sales"])
      assert_equal("::Order", constant.name)
      assert_equal("components/sales/app/models/order.rb", constant.location)
      assert_equal("components/sales", constant.package.name)
    end

    test "raises with helpful message if there are errors resolving constants" do
      use_template(:ambiguous)

      error = assert_raises(ConstantDiscovery::Error) do
        discovery.context_for("Order")
      end

      assert_match(/Ambiguous constant definition/, error.message)
    end

    test "raises when validating constants and load paths contain no ruby files" do
      use_template(:skeleton)

      empty_loader = Zeitwerk::Loader.new
      empty_loader.setup

      with_empty_load_paths = ConstantDiscovery.new(
        PackageSet.load_all_from(app_dir),
        root_path: app_dir,
        loaders:   [empty_loader]
      )

      error = assert_raises(ConstantDiscovery::Error) do
        with_empty_load_paths.validate_constants
      end

      assert_match(/Could not find any ruby files/, error.message)
    end

    test "raises when validating constants that include an ambiguous reference" do
      use_template(:ambiguous)

      error = assert_raises(ConstantDiscovery::Error) do
        discovery.validate_constants
      end

      assert_match(/Ambiguous constant definition/, error.message)
    end

    private

    def discovery
      yield(Rails.autoloaders.main) if block_given?

      ConstantDiscovery.new(
        PackageSet.load_all_from(app_dir),
        root_path: app_dir,
        loaders:   Rails.autoloaders
      )
    end
  end
end
