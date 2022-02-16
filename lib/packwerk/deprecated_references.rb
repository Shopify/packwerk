# typed: strict
# frozen_string_literal: true

require "yaml"

module Packwerk
  class DeprecatedReferences
    extend T::Sig

    ENTRIES_TYPE = T.type_alias do
      T::Hash[String, T.untyped]
    end

    sig { params(package: Packwerk::Package, filepath: String).void }
    def initialize(package, filepath)
      @package = package
      @filepath = filepath
      @new_entries = T.let({}, ENTRIES_TYPE)
      @deprecated_references = T.let(nil, T.nilable(ENTRIES_TYPE))
    end

    sig do
      params(reference: Packwerk::Reference, violation_type: ViolationType)
        .returns(T::Boolean)
    end
    def listed?(reference, violation_type:)
      violated_constants_found = deprecated_references.dig(reference.constant.package.name, reference.constant.name)
      return false unless violated_constants_found

      violated_constant_in_file = violated_constants_found.fetch("files", []).include?(reference.relative_path)
      return false unless violated_constant_in_file

      violated_constants_found.fetch("violations", []).include?(violation_type.serialize)
    end

    sig { params(reference: Packwerk::Reference, violation_type: Packwerk::ViolationType).returns(T::Boolean) }
    def add_entries(reference, violation_type)
      package_violations = @new_entries.fetch(reference.constant.package.name, {})
      entries_for_file = package_violations[reference.constant.name] ||= {}

      entries_for_file["violations"] ||= []
      entries_for_file["violations"] << violation_type.serialize

      entries_for_file["files"] ||= []
      entries_for_file["files"] << reference.relative_path.to_s

      @new_entries[reference.constant.package.name] = package_violations
      listed?(reference, violation_type: violation_type)
    end

    sig { returns(T::Boolean) }
    def stale_violations?
      prepare_entries_for_dump
      deprecated_references.any? do |package, package_violations|
        package_violations.any? do |constant_name, entries_for_file|
          new_entries_violation_types = @new_entries.dig(package, constant_name, "violations")
          return true if new_entries_violation_types.nil?
          if entries_for_file["violations"].all? { |type| new_entries_violation_types.include?(type) }
            stale_violations =
              entries_for_file["files"] - Array(@new_entries.dig(package, constant_name, "files"))
            stale_violations.any?
          else
            return true
          end
        end
      end
    end

    sig { void }
    def dump
      if @new_entries.empty?
        File.delete(@filepath) if File.exist?(@filepath)
      else
        prepare_entries_for_dump
        message = <<~MESSAGE
          # This file contains a list of dependencies that are not part of the long term plan for #{@package.name}.
          # We should generally work to reduce this list, but not at the expense of actually getting work done.
          #
          # You can regenerate this file using the following command:
          #
          # bin/packwerk update-deprecations #{@package.name}
        MESSAGE
        File.open(@filepath, "w") do |f|
          f.write(message)
          f.write(@new_entries.to_yaml)
        end
      end
    end

    private

    sig { returns(ENTRIES_TYPE) }
    def prepare_entries_for_dump
      @new_entries.each do |package_name, package_violations|
        package_violations.each do |_, entries_for_file|
          entries_for_file["violations"].sort!.uniq!
          entries_for_file["files"].sort!.uniq!
        end
        @new_entries[package_name] = package_violations.sort.to_h
      end

      @new_entries = @new_entries.sort.to_h
    end

    sig { returns(ENTRIES_TYPE) }
    def deprecated_references
      @deprecated_references ||= if File.exist?(@filepath)
        load_yaml(@filepath)
      else
        {}
      end
    end

    sig { params(filepath: String).returns(ENTRIES_TYPE) }
    def load_yaml(filepath)
      YAML.load_file(filepath) || {}
    rescue Psych::Exception
      {}
    end
  end
end
