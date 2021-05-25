# typed: false
# frozen_string_literal: true

require "test_helper"

module Packwerk
  module Inflections
    class CustomTest < Minitest::Test
      test "#initialize with nil inflection file returns empty inflections" do
        empty_inflection = Packwerk::Inflections::Custom.new
        assert_empty empty_inflection.inflections
      end

      test "#initialize with non-existant inflection file returns empty inflections" do
        empty_inflection = Packwerk::Inflections::Custom.new("this/file/doesn't exist")
        assert_empty empty_inflection.inflections
      end

      test "#initialize with an empty inflection file returns empty inflections" do
        Tempfile.create("test_file.yml") do |file|
          empty_inflection = Packwerk::Inflections::Custom.new(file.path)
          assert_empty empty_inflection.inflections
        end
      end

      test "#initialize with inflection file containing invalid keys raises exception" do
        Tempfile.create("test_file.yml") do |file|
          file.write("---\n:an_invalid_key:\n- value\n")
          file.flush

          assert_raises ArgumentError do
            Packwerk::Inflections::Custom.new(file.path)
          end
        end
      end

      test "#apply_to applies inflections" do
        inflections = ActiveSupport::Inflector::Inflections.new

        customs = Packwerk::Inflections::Custom.new

        customs.inflections = {
          plural: [%w(analysis analyses)],
          acronym: ["PKG"],
          singular: [[/status$/, "status"]],
        }

        customs.apply_to(inflections)

        assert_equal(
          [%w(analysis analyses)],
          inflections.plurals
        )

        assert_equal(
          { "pkg" => "PKG" },
          inflections.acronyms
        )

        assert_equal(
          [[/status$/, "status"]],
          inflections.singulars
        )
      end
    end
  end
end
