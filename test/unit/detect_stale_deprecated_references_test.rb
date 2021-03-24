# typed: false
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class DetectStaleDeprecatedReferencesTest < Minitest::Test
    setup do
      package = Package.new(name: "buyers", config: {})
      violated_reference =
        Reference.new(
          nil,
          "orders/app/jobs/orders/sweepers/purge_old_document_rows_task.rb",
          ConstantDiscovery::ConstantContext.new(
            "::Buyers::Document",
            "autoload/buyers/document.rb",
            package,
            false
          )
        )
      deprecated_reference = DeprecatedReferences.new(package, "test/fixtures/deprecated_references.yml")
      deprecated_reference.add_entries(violated_reference, "dependency")
      @detect_stale_deprecated_references = DetectStaleDeprecatedReferences.new(
        ".",
        { package.name => deprecated_reference }
      )
    end
  end
end
