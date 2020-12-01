# typed: ignore
# frozen_string_literal: true

require "test_helper"
require "parser_test_helper"

require "packwerk/node"

module Packwerk
  class ReferenceExtractorTest < Minitest::Test
    include ApplicationFixtureHelper

    def setup
      setup_application_fixture
      use_template(:skeleton)

      load_paths =
        Dir.glob(to_app_path("components/*/{app,test}/*{/concerns,}"))
          .map { |p| Pathname.new(p).relative_path_from(app_dir).to_s }

      resolver = ConstantResolver.new(root_path: app_dir, load_paths: load_paths)
      packages = ::Packwerk::PackageSet.load_all_from(app_dir)

      @context_provider = ::Packwerk::ConstantDiscovery.new(
        constant_resolver: resolver,
        packages: packages
      )
    end

    def teardown
      teardown_application_fixture
    end

    test "finds simple cross package references" do
      references = process(
        "class Entry; Order.find(1); end",
        "components/timeline/app/models/entry.rb",
      )

      assert_equal 1, references.count

      reference = references.first
      assert_equal "components/timeline", reference.source_package.name
      assert_equal "::Order", reference.constant.name
      assert_equal "components/sales", reference.constant.package.name
      assert_equal "components/sales/app/models/order.rb", reference.constant.location
    end

    test "reports nested constants only once" do
      references = process(
        "class Entry; Order::Extension.new; end",
        "components/timeline/app/models/entry.rb"
      )

      assert_equal 1, references.count

      reference = references.first
      assert_equal "::Order::Extension", reference.constant.name
    end

    test "reports properly on 'self anchored' constants" do
      references = process(
        "class Entry; self::SOME_CONSTANT = :a; end",
        "components/timeline/app/models/entry.rb"
      )

      assert_equal 0, references.count
    end

    test "handles inherited class constants in the surrounding namespace" do
      references = process(
        "module Sales; class Order < Error; end; end",
        "components/timeline/app/models/sales/order.rb"
      )

      # Error in `class Order < Error` should be referencing ::Error, not ::Sales::Order::Error, so
      # we expect only a single reference for Order
      assert_equal 1, references.length
      assert_equal "::Sales::Order", references.first.constant.name
    end

    test "handles bare constants, as present in .erb files" do
      references = process(
        "Order",
        "components/timeline/app/models/something.rb",
      )

      assert_equal 1, references.count

      reference = references.first
      assert_equal "components/timeline", reference.source_package.name
      assert_equal "::Order", reference.constant.name
      assert_equal "components/sales", reference.constant.package.name
      assert_equal "components/sales/app/models/order.rb", reference.constant.location
    end

    test "treats class name in definition as fully qualified via its parent modules when it exists" do
      references = process(
        "module Sales; class Order; end; end",
        "components/timeline/app/models/sales/order.rb"
      )

      assert_equal 1, references.count

      reference = references.first
      # Does not resolve to `::Order`
      assert_equal "::Sales::Order", reference.constant.name
    end

    test "treats class name in definition in block as fully qualified via its parent modules" do
      references = process(
        "module Imaginary; -> { module Sales; class Order; end; end }; end",
        "components/timeline/app/models/imaginary.rb"
      )

      # Does not resolve to `::Sales::Order`, which would be cross package reference
      assert_empty references
    end

    test "recognizes locally defined constants" do
      references = process(
        "module Something; class Order; end; Order.new; end",
        "components/timeline/app/models/something.rb"
      )

      # Should not resolve to `::Order`, which is defined in `sales`
      assert_empty references
    end

    test "recognizes locally defined nested constants" do
      references = process(
        "class Something::Order; end; module Something; Order.new; end",
        "components/timeline/app/models/something.rb"
      )

      # Should not resolve to `::Order`, which is defined in `sales`
      assert_empty references
    end

    test "recognizes locally assigned constants" do
      references = process(
        "module Something; Order = Struct.new; Order.new; end",
        "components/timeline/app/models/something.rb"
      )

      # Should not resolve to `::Order`, which is defined in `sales`
      assert_empty references
    end

    test "resolves associations in the current namespace path" do
      references = process(
        "module Sales; class TheThing; has_lots :orders; end; end",
        "components/timeline/app/models/entry.rb",
        [DummyAssociationInspector.new(association: true, reference_name: "Order")]
      )

      assert_equal 1, references.count

      reference = references.first
      # does not refer to ::Order, which also exists
      assert_equal "::Sales::Order", reference.constant.name
    end

    test "passes all arguments to association inspector" do
      call = "has_many :clowns, class_name: 'Order'"
      arguments = Node.method_arguments(ParserTestHelper.parse(call))
      process(
        "class Entry; #{call}; end",
        "components/timeline/app/models/entry.rb",
        [DummyAssociationInspector.new(association: true, expected_args: arguments)]
      )
    end

    test "ignores unknown constants" do
      references = process(
        "class LineItem; String.new; end",
        "components/sales/app/models/line_item.rb"
      )

      assert_empty references
    end

    test "uses all constant name inspectors to determine constant name" do
      references = process(
        "class Entry; has_many :sales_entries; end",
        "components/timeline/app/models/entry.rb",
        [
          DummyAssociationInspector.new(association: false, reference_name: "Order"),
          DummyAssociationInspector.new(association: true, reference_name: "Sales::Entry"),
        ]
      )

      assert_equal 1, references.count

      reference = references.first
      assert_equal "::Sales::Entry", reference.constant.name
    end

    test "uses first inspector for constant name if multiple match" do
      references = process(
        "class Entry; has_many :orders; end",
        "components/timeline/app/models/entry.rb",
        [
          DummyAssociationInspector.new(association: true, reference_name: "Order"),
          DummyAssociationInspector.new(association: true, reference_name: "Sales::Entry"),
        ]
      )

      assert_equal 1, references.count

      reference = references.first
      assert_equal "::Order", reference.constant.name
    end

    private

    class DummyAssociationInspector
      include Packwerk::ConstantNameInspector

      def initialize(association: false, reference_name: "Dummy", expected_args: nil)
        @association = association
        @reference_name = reference_name
        @expected_args = expected_args
      end

      def constant_name_from_node(node, ancestors:)
        return nil unless @association
        return nil unless Node.method_call?(node)

        args = Node.method_arguments(node)
        if @expected_args && @expected_args != args
          raise("expected arguments don't match.\nExpected:\n#{@expected_args}\nActual:\n#{args}")
        end

        @reference_name
      end
    end

    DEFAULT_INSPECTORS = [ConstNodeInspector.new, DummyAssociationInspector.new]

    def process(code, file_path, constant_name_inspectors = DEFAULT_INSPECTORS)
      root_node = ParserTestHelper.parse(code)
      file_path = to_app_path(file_path)

      extractor = ::Packwerk::ReferenceExtractor.new(
        context_provider: @context_provider,
        constant_name_inspectors: constant_name_inspectors,
        root_node: root_node,
        root_path: app_dir
      )

      find_references_in_ast(root_node, ancestors: [], extractor: extractor, file_path: file_path)
    end

    def find_references_in_ast(root_node, ancestors:, extractor:, file_path:)
      references = [extractor.reference_from_node(root_node, ancestors: ancestors, file_path: file_path)]

      child_references = Node.each_child(root_node).flat_map do |child|
        find_references_in_ast(child, ancestors: [root_node] + ancestors, extractor: extractor, file_path: file_path)
      end

      (references + child_references).compact
    end
  end
end
