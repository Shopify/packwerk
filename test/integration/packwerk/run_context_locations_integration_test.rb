# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  # Integration tests verifying that line/column locations reported in offenses
  # match the 1-based convention Packwerk uses for display.
  #
  # Both Rubydex (constant references) and Prism (association references) report
  # locations with their own conventions, and we need to normalize them:
  # - Rubydex: 0-based line and 0-based column
  # - Prism:   1-based line and 0-based column
  class RunContextLocationsIntegrationTest < Minitest::Test
    include ApplicationFixtureHelper

    setup do
      setup_application_fixture
      use_template(:blank)
    end

    teardown do
      teardown_application_fixture
    end

    test "reports 1-based line and column for plain constant references (Rubydex source)" do
      # Set up two packages with a cross-package constant reference.
      # The reference to `Target` is on line 5 of source.rb at column 3 (1-based).
      write_app_file("packs/source/package.yml", <<~YML)
        enforce_dependencies: true
      YML
      write_app_file("packs/target/package.yml", <<~YML)
        enforce_dependencies: true
      YML
      write_app_file("packs/target/app/models/target.rb", <<~RUBY)
        class Target
        end
      RUBY
      # Lines: 1=class, 2=blank, 3="def..", 4=blank, 5="  Target.new" (col 3 is 'T')
      write_app_file("packs/source/app/models/source.rb", <<~RUBY)
        class Source
          def call

            Target.new
          end
        end
      RUBY

      offenses = run_check

      target_offense = offenses.find { |o| o.message.include?("::Target") }
      refute_nil(target_offense, "expected a violation for ::Target")

      assert_equal(
        "packs/source/app/models/source.rb",
        target_offense.file,
      )
      location = target_offense.location
      refute_nil(location, "expected a source location on the offense")
      assert_equal(4, location.line, "Target.new is on line 4 of source.rb (1-based)")
      assert_equal(5, location.column, "Target.new starts at column 5 of source.rb (1-based)")
    end

    test "reports 1-based line and column for association references (Prism source)" do
      # Set up two packages where the source uses a Rails-style association.
      # The `belongs_to :target` is on line 2 of source.rb at column 3 (1-based).
      write_app_file("packs/source/package.yml", <<~YML)
        enforce_dependencies: true
      YML
      write_app_file("packs/target/package.yml", <<~YML)
        enforce_dependencies: true
      YML
      write_app_file("packs/target/app/models/target.rb", <<~RUBY)
        class Target
        end
      RUBY
      write_app_file("packs/source/app/models/source.rb", <<~RUBY)
        class Source
          belongs_to :target
        end
      RUBY

      offenses = run_check

      target_offense = offenses.find { |o| o.message.include?("::Target") }
      refute_nil(target_offense, "expected a violation for ::Target via belongs_to :target")

      assert_equal(
        "packs/source/app/models/source.rb",
        target_offense.file,
      )
      location = target_offense.location
      refute_nil(location, "expected a source location on the offense")
      assert_equal(2, location.line, "belongs_to :target is on line 2 of source.rb (1-based)")
      assert_equal(3, location.column, "belongs_to starts at column 3 of source.rb (1-based)")
    end

    private

    def run_check
      file_set = Set.new(Dir.glob("packs/**/*.rb"))
      run_context = RunContext.from_configuration(config)
      run_context.index_and_resolve(file_set)
      run_context.find_offenses(file_set)
    end
  end
end
