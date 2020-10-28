# typed: strict
# frozen_string_literal: true

module Packwerk
  # Exracts the constant reference from a fixture call
  class FixtureReferenceInspector
    class FixturePathIndex
      extend T::Sig

      sig { params(base: String).void }
      def initialize(base)
        @base = T.let(base, String)
      end

      sig { params(method_name: String).returns(T.nilable(String)) }
      def find_by!(method_name:)
        return unless (relative_fixture_path = fixtures_by_method_names[method_name])

        relative_fixture_path
      end

      private

      sig { returns(String) }
      attr_reader :base

      sig { returns(T::Hash[String, String]) }
      def fixtures_by_method_names
        @fixtures_by_method_names = T.let(@fixtures_by_method_names, T.nilable(T::Hash[String, String]))

        @fixtures_by_method_names ||= retrieve_fixture_files_for_methods
      end

      sig { returns(T::Hash[String, String]) }
      def retrieve_fixture_files_for_methods
        fixture_files.each_with_object({}) do |file_path, hash|
          key = method_name_from_path(file_path)
          hash[key] = file_path
        end
      end

      sig { params(path: String).returns(String) }
      def method_name_from_path(path)
        path_without_extension = path[0...-4]
        T.must(path_without_extension).gsub("/", "_")
      end

      sig { returns(T::Array[String]) }
      def fixture_files
        Dir.glob("**/*.yml", base: base)
      end
    end
  end
end
