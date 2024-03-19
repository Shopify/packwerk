# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class ReferencesFromFileTest < Minitest::Test
    setup do
      config = Configuration.new
      config.stubs(:load_paths).returns({})
      @run_context = RunContext.from_configuration(config)
      RunContext.stubs(:from_configuration).with(config).returns(@run_context)
      @referencer = ReferencesFromFile.new(config)
    end

    test "raises on parser error" do
      offense = Offense.new(file: "something.rb", message: "yo")
      @run_context.stubs(:references_from_file).returns(
        RunContext::FileReferencesResult.new(file_offenses: [offense], references: [])
      )

      assert_raises ReferencesFromFile::FileParserError do
        @referencer.list("lib/something.rb")
      end
    end

    test "fetches violations for all files from run context" do
      references = {
        "lib/something.rb" => [
          make_fake_reference,
        ],
        "components/ice_cream_sales/app/models/scoop.rb" => [
          make_fake_reference,
        ],
      }
      @referencer.stubs(:files).returns(references.keys)

      references.each do |file, references|
        @run_context.stubs(:references_from_file).with(relative_file: file).returns(
          RunContext::FileReferencesResult.new(file_offenses: [], references: references)
        )
      end

      assert_equal Set.new(references.values.flatten), Set.new(@referencer.list_all)
    end

    private

    def make_fake_reference
      package_name = Array("ilikeletters".chars.sample(5)).join
      Reference.new(
        package: Package.new(name: package_name),
        relative_path: package_name,
        constant: ConstantContext.new,
        source_location: nil
      )
    end
  end
end
