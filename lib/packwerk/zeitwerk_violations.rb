# typed: true
# frozen_string_literal: true

require "pathname"
require "yaml"

module Packwerk
  class ZeitwerkViolations
    extend T::Sig

    sig { params(filepath: String, root_path: String).void }
    def initialize(filepath, root_path:)
      @filepath = filepath
      @root_path = root_path
      @new_entries = {}
    end

    sig { returns(Hash) }
    def zeitwerk_violations
      @zeitwerk_violations ||= if File.exist?(@filepath)
        YAML.load_file(@filepath) || {}
      else
        {}
      end
    end

    sig { params(offense: ZeitwerkOffense).returns(T::Boolean) }
    def add_entries(offense)
      location = offense.relative_location_from(@root_path)
      @new_entries[location] = { constant: offense.constant }

      listed?(offense)
    end

    sig { params(offense: ZeitwerkOffense).returns(T::Boolean) }
    def listed?(offense)
      location = offense.relative_location_from(@root_path)
      zeitwerk_violations[location] == { constant: offense.constant }
    end

    sig { void }
    def dump
      if @new_entries.empty?
        File.delete(@filepath) if File.exist?(@filepath)
      else
        message = <<~MESSAGE
          # This file contains a list of constants definitions which do not
          # conform to Zeitwerk conventions.
          #
          # Packwerk will fail to recognize these class and module definitions
          # and assume they exist outside the main application.
          #
          # We should generally work to reduce this list, but not at the expense of
          # actually getting work done.
          #
          #
          # You can regenerate this file using the following command:
          #
          # bundle exec packwerk update-zeitwerk-violations
        MESSAGE
        File.open(@filepath, "w") do |f|
          f.write(message)
          f.write(@new_entries.to_yaml)
        end
      end
    end
  end
end
