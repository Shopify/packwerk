# typed: ignore
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class PrivacyCheckerTest < Minitest::Test
    setup do
      @temp_dir = Dir.mktmpdir
      FileUtils.cp_r("test/fixtures/skeleton", @temp_dir)
      @root_path = File.join(@temp_dir, "skeleton/")
      @reference_lister = CheckingDeprecatedReferences.new(@root_path)
      @source_package = Package.new(name: "source_package", config: {})
    end

    teardown do
      FileUtils.remove_entry(@temp_dir)
    end

    test "ignores if destination package is not enforcing" do
      destination_package = Package.new(name: "destination_package", config: { "enforce_privacy" => false })
      checker = privacy_checker

      reference =
        Reference.new(
          @source_package,
          "some/path.rb",
          ConstantDiscovery::ConstantContext.new(
            "::SomeName",
            "some/location.rb",
            destination_package,
            false
          )
        )

      refute checker.invalid_reference?(reference, @reference_lister)
    end

    test "ignores if destination package is only enforcing for other constants" do
      destination_package = Package.new(
        name: "destination_package",
        config: { "enforce_privacy" => ["::OtherConstant"] }
      )
      checker = privacy_checker

      reference =
        Reference.new(
          @source_package,
          "some/path.rb",
          ConstantDiscovery::ConstantContext.new(
            "::SomeName",
            "some/location.rb",
            destination_package,
            false
          )
        )

      refute checker.invalid_reference?(reference, @reference_lister)
    end

    test "complains about private constant if enforcing privacy for everything" do
      destination_package = Package.new(name: "destination_package", config: { "enforce_privacy" => true })
      checker = privacy_checker

      reference =
        Reference.new(
          @source_package,
          "some/path.rb",
          ConstantDiscovery::ConstantContext.new(
            "::SomeName",
            "some/location.rb",
            destination_package,
            false
          )
        )

      assert checker.invalid_reference?(reference, @reference_lister)
    end

    test "complains about private constant if enforcing for specific constants" do
      destination_package = Package.new(name: "destination_package", config: { "enforce_privacy" => ["::SomeName"] })
      checker = privacy_checker

      reference =
        Reference.new(
          @source_package,
          "some/path.rb",
          ConstantDiscovery::ConstantContext.new(
            "::SomeName",
            "some/location.rb",
            destination_package,
            false
          )
        )

      assert checker.invalid_reference?(reference, @reference_lister)
    end

    test "complains about nested constant if enforcing for specific constants" do
      destination_package = Package.new(name: "destination_package", config: { "enforce_privacy" => ["::SomeName"] })
      checker = privacy_checker

      reference =
        Reference.new(
          @source_package,
          "some/path.rb",
          ConstantDiscovery::ConstantContext.new(
            "::SomeName::SomeOtherThing",
            "some/location.rb",
            destination_package,
            false
          )
        )

      assert checker.invalid_reference?(reference, @reference_lister)
    end

    test "ignores constant that starts like enforced constant" do
      destination_package = Package.new(name: "destination_package", config: { "enforce_privacy" => ["::SomeName"] })
      checker = privacy_checker

      reference =
        Reference.new(
          @source_package,
          "some/path.rb",
          ConstantDiscovery::ConstantContext.new(
            "::SomeNameButNotQuite",
            "some/location.rb",
            destination_package,
            false
          )
        )

      refute checker.invalid_reference?(reference, @reference_lister)
    end

    test "ignores public constant even if enforcing privacy for everything" do
      destination_package = Package.new(name: "destination_package", config: { "enforce_privacy" => true })
      checker = privacy_checker

      reference =
        Reference.new(
          @source_package,
          "some/path.rb",
          ConstantDiscovery::ConstantContext.new(
            "::SomeName",
            "some/location.rb",
            destination_package,
            true
          )
        )

      refute checker.invalid_reference?(reference, @reference_lister)
    end

    test "only checks the deprecated references file for private constants" do
      destination_package = Package.new(name: "destination_package", config: { "enforce_privacy" => ["::Foo::Bar"] })
      checker = privacy_checker

      reference =
        Reference.new(
          @source_package,
          "some/path.rb",
          ConstantDiscovery::ConstantContext.new(
            "::Foo::Bar",
            "some/location.rb",
            destination_package,
            false
          )
        )

      @reference_lister.expects(:listed?).with(reference, violation_type: ViolationType::Privacy).once

      checker.invalid_reference?(reference, @reference_lister)
    end

    test "generates nice message for violation" do
      destination_package = Package.new(name: "destination_package", config: { "enforce_privacy" => true })
      checker = privacy_checker

      reference =
        Reference.new(
          @source_package,
          "some/path.rb",
          ConstantDiscovery::ConstantContext.new(
            "::SomeName",
            "some/location.rb",
            destination_package,
            false
          )
        )

      assert_match(
        "Privacy violation: '::SomeName' is private to 'destination_package' but referenced from " \
          "'source_package'.",
        checker.message_for(reference)
      )
    end

    private

    def privacy_checker
      PrivacyChecker.new
    end
  end
end
