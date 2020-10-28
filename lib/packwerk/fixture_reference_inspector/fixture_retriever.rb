# typed: strict
# frozen_string_literal: true

require "packwerk/fixture_reference_inspector/fixture_path_index"
require "packwerk/fixture_reference_inspector/fixture"

module Packwerk
  # Exracts the constant reference from a fixture call
  class FixtureReferenceInspector
    class FixtureRetriever
      extend T::Sig

      sig { params(base: String).void }
      def initialize(base)
        @base = T.let(base, String)
      end

      sig { params(method_name: String).returns(T.nilable(Fixture)) }
      def find_by!(method_name:)
        return unless (relative_fixture_path = fixture_path_index.find_by!(method_name: method_name))

        retrieve_fixture(relative_fixture_path)
      end

      private

      sig { returns(String) }
      attr_reader :base

      sig { returns(FixturePathIndex) }
      def fixture_path_index
        @fixture_path_index = T.let(@fixture_path_index, T.nilable(FixturePathIndex))

        @fixture_path_index ||= FixturePathIndex.new(base)
      end

      sig { params(path: String).returns(Fixture) }
      def retrieve_fixture(path)
        @fixtures = T.let(@fixtures, T.nilable(T::Hash[String, Fixture]))

        @fixtures ||= Hash.new { |h, key| h[key] = load_fixture(path) }
        @fixtures[path]
      end

      sig { params(path: String).returns(Fixture) }
      def load_fixture(path)
        fixture_path = File.join(base, path)
        content = YAML.load_file(fixture_path)
        Fixture.new(content: content, path: path)
      end
    end
  end
end
