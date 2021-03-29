# typed: false
# frozen_string_literal: true

require "test_helper"
require "packwerk/cache_deprecated_references"

module Packwerk
  class CacheDeprecatedReferencesTest < Minitest::Test
    setup do
      @cache_deprecated_references = CacheDeprecatedReferences.new(".")
      @source_package = Package.new(name: "source_package", config: {})
      @destination_package = Package.new(name: "destination_package", config: {})
      @reference =
        Reference.new(
          @source_package,
          "some/path.rb",
          ConstantDiscovery::ConstantContext.new(nil, nil, @destination_package, false)
        )
      @offense = ReferenceOffense.new(reference: @reference, violation_type: ViolationType::Dependency)
    end

    test "#add_offense adds entry" do
      File.stubs(:open)

      Packwerk::DeprecatedReferences.any_instance
        .expects(:add_entries)
        .with(@offense)

      @cache_deprecated_references.add_offense(@offense)
    end

    test "#stale_violations? returns true if there are stale violations" do
      @cache_deprecated_references.add_offense(@offense)

      Packwerk::DeprecatedReferences.any_instance
        .expects(:stale_violations?)
        .returns(true)

      assert @cache_deprecated_references.stale_violations?
    end

    test "#stale_violations? returns false if no stale violations" do
      @cache_deprecated_references.add_offense(@offense)

      Packwerk::DeprecatedReferences.any_instance
        .expects(:stale_violations?)
        .returns(false)

      refute @cache_deprecated_references.stale_violations?
    end

    test "#listed? returns true if constant is listed in file" do
      reference =
        Reference.new(
          @source_package,
          "some/path.rb",
          ConstantDiscovery::ConstantContext.new(nil, nil, nil, false)
        )

      offense = ReferenceOffense.new(reference: reference, violation_type: ViolationType::Dependency)

      deprecated_references = Packwerk::DeprecatedReferences.new(@source_package, ".")
      deprecated_references
        .stubs(:listed?)
        .with(offense)
        .returns(true)
      Packwerk::DeprecatedReferences
        .stubs(:new)
        .with(@source_package, "./source_package/deprecated_references.yml")
        .returns(deprecated_references)

      assert @cache_deprecated_references.listed?(offense)
    end

    test "#listed? returns false if constant is not listed in file " do
      reference =
        Reference.new(
          @source_package,
          "some/path.rb",
          ConstantDiscovery::ConstantContext.new(
            "::SomeName",
            "some/location.rb",
            @destination_package,
            false
          )
        )

      offense = ReferenceOffense.new(reference: reference, violation_type: ViolationType::Dependency)

      refute @cache_deprecated_references.listed?(offense)
    end
  end
end
