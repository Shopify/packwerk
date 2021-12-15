# typed: strict
# frozen_string_literal: true

require "yaml"

module Packwerk
  module RailsDependencies
    # This should *only* be used by `dump.rake`. Nothing else should be calling into this class.
    class Dump
      extend T::Sig

      SUPPORTED_INFLECTION_METHODS = T.let(%w(acronyms humans irregulars plurals singulars uncountables),
        T::Array[String])

      sig { void }
      def self.dump!
        load_paths = ApplicationLoadPaths.extract_relevant_paths
        inflections = ActiveSupport::Inflector.inflections

        dependencies = {
          load_paths: load_paths,
          inflections: inflections,
        }

        FileUtils.mkdir_p(DUMP_DIRECTORY)
        File.open(DUMP_FILE, "w") do |file|
          file.write(YAML.dump(dependencies))
        end
      end
    end
  end
end
