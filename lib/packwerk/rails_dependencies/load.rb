# typed: strict
# frozen_string_literal: true

module Packwerk
  module RailsDependencies
    class Load
      extend T::Sig

      sig { returns(Result) }
      def self.load!
        require 'pry'
        raw_file_contents = File.read(DUMP_FILE);
        parsed_file_contents = YAML.load(raw_file_contents);
        inflector = Inflector.new(parsed_file_contents[:inflections])
        Result.new(load_paths: parsed_file_contents[:load_paths], inflector: inflector)
      end
    end
  end
end
