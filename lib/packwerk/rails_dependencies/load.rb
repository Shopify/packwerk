# typed: strict
# frozen_string_literal: true

module Packwerk
  module RailsDependencies
    class Load
      extend T::Sig

      # Right now this is an unstructured hash. We might instead use a T::Struct here so we don't need metaprogramming below.
      InflectionsJson = T.type_alias do
        T::Hash[T.untyped, T.untyped]
      end

      sig { params(json: InflectionsJson).returns(Inflector) }
      def self.load_inflections_from_json(json)
        inflection_type_to_method_map = {
          'acronyms' => 'acronym',
          'humans' => 'human',
          'irregulars' => 'irregular',
          'plurals' => 'plural',
          'singulars' => 'singular',
          'uncountables' => 'uncountable'
        }

        inflections = ActiveSupport::Inflector::Inflections.new
        T.unsafe(json).slice(*inflection_type_to_method_map.keys).each do |inflection_type, inflections_list|
          inflection_method = inflection_type_to_method_map.fetch(inflection_type)

          # Acronyms are special and serialize to JSON in a way that is inconsistent with the API to add the inflection
          if inflection_type == 'acronyms'
            inflections_list = inflections_list.keys
          end

          inflections_list.each do |inflection|
            T.unsafe(inflections).public_send(inflection_method, *Array(inflection))
          end
        end

        Inflector.new(inflections)
      end

      sig { returns(Result) }
      def self.load!
        require 'pry'
        raw_file_contents = File.read(DUMP_FILE);
        parsed_file_contents = JSON.parse(raw_file_contents);
        inflector = self.load_inflections_from_json(parsed_file_contents['inflections'])
        Result.new(load_paths: parsed_file_contents['load_paths'], inflector: inflector)
      end
    end
  end
end
