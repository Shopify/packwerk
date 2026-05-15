# typed: true
# frozen_string_literal: true

require "test_helper"
require "support/rails_test_helper"

module Packwerk
  # Integration tests that document and exercise the constant reference detection
  # behaviors that differ from the pre-Rubydex pipeline. Each test sets up a tiny
  # 2-package fixture and runs `packwerk check` via the public CLI so the test
  # describes user-visible behavior rather than internal API details.
  class RunContextDetectionIntegrationTest < Minitest::Test
    include ApplicationFixtureHelper

    setup do
      @out = StringIO.new
      setup_application_fixture
      use_template(:skeleton)
    end

    teardown do
      teardown_application_fixture
    end

    test "reports each namespace prefix in a nested constant reference as a separate offense" do
      # The pre-Rubydex pipeline (ConstNodeInspector) only extracted the ROOT of a
      # namespaced constant. So `Foo::Bar::Baz.new` produced one violation for `Foo`.
      # The Rubydex-based pipeline produces a violation for each prefix:
      # `Foo`, `Foo::Bar`, `Foo::Bar::Baz`. This more accurately reflects what the
      # source code references, and lets package owners of intermediate namespaces
      # surface their own dependency violations.
      write_app_file(
        "components/timeline/app/models/timeline/uses_nested_target.rb",
        <<~RUBY,
          class Timeline::UsesNestedTarget
            def call
              Sales::Order::Error.new
            end
          end
        RUBY
      )

      run_packwerk_check
      target_offenses = captured_output.lines.grep(/Dependency violation: ::Sales/)

      assert_equal(3, target_offenses.size,
        "expected one offense per namespace prefix " \
          "(::Sales, ::Sales::Order, ::Sales::Order::Error), " \
          "got:\n#{captured_output}")
    end

    test "reports namespace prefixes inside ERB constant references" do
      # ERB files contribute a large share of new offenses on real codebases
      # because they typically reference deeply-namespaced constants like
      # `Foo::Bar::CONSTANT` from view helpers and template strings. With prefix
      # expansion (see the test above), each such reference produces one offense
      # per namespace level, multiplying ERB-related offenses considerably.
      merge_into_app_yaml_file("packwerk.yml", { "include" => ["**/*.rb", "**/*.erb"] })
      write_app_file(
        "components/timeline/app/views/timeline/index.html.erb",
        <<~ERB,
          <h1><%= Sales::Order::Error.name %></h1>
        ERB
      )

      run_packwerk_check
      target_offenses = captured_output.lines.grep(/Dependency violation: ::Sales/)

      assert_equal(3, target_offenses.size,
        "expected one offense per namespace prefix from the ERB reference, " \
          "got:\n#{captured_output}")
    end

    test "does not flag namespace reopenings that match a definition in the source package" do
      # Regression test: shared namespaces (like `Checkouts`, `GraphApi`) are
      # commonly defined as containers in multiple packages. A file that reopens
      # `module Sales; class LocalThing; end; end` from inside a package that ALSO
      # defines part of `Sales` should not produce a cross-package violation
      # against the namespace itself. The old pipeline got this right via Zeitwerk
      # path conventions; the new pipeline does it by checking if any definition
      # of the constant lives in the source file's package.
      #
      # An earlier iteration of the new pipeline regressed this and produced ~219k
      # bogus offenses on the Shopify monolith; this test guards against
      # reintroducing that bug.

      # Add a `Sales` definition to the timeline package, alongside its existing
      # definition in the sales package, so the namespace is genuinely shared.
      write_app_file(
        "components/timeline/app/models/sales/from_timeline.rb",
        <<~RUBY,
          module Sales
            class FromTimeline
            end
          end
        RUBY
      )

      run_packwerk_check
      sales_offenses = captured_output.lines.grep(/Dependency violation: ::Sales\b/)

      assert_empty(
        sales_offenses,
        "expected no ::Sales offenses for a file in a package that itself defines part of ::Sales, " \
          "got:\n#{captured_output}",
      )
    end

    private

    def run_packwerk_check
      Packwerk::Cli.new(out: @out).run(["check"])
    rescue SystemExit
      # CLI may exit; we inspect captured_output for assertions
    end

    def captured_output
      @out.string
    end
  end
end
