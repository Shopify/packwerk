# typed: strict
# frozen_string_literal: true

require "yaml"

module Packwerk
  module RailsDependencies
    # This should *only* be used by `dump.rake`. Nothing else should be calling into this class.
    class Dump
      extend T::Sig

      SUPPORTED_INFLECTION_METHODS = T.let(%w(acronyms humans irregulars plurals singulars uncountables), T::Array[String])

      sig { void }
      def self.dump!
        Packwerk::Diagnostics.log('Running Dump.dump!', __FILE__)
        load_paths = ApplicationLoadPaths.extract_relevant_paths("test")
        inflections = ActiveSupport::Inflector.inflections.as_json

        dependencies = {
          load_paths: load_paths,
          inflections: inflections
        }

        File.open(DUMP_FILE, 'w') do |file|
          file.write dependencies.to_json
        end

        Packwerk::Diagnostics.log('Finished running Dump.dump!', __FILE__)
      end
    end
  end
end
