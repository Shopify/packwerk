# typed: strict
# frozen_string_literal: true

require "yaml"

module Packwerk
  class PackageTodo
    extend T::Sig

    EntriesType = T.type_alias do
      T::Hash[String, T.untyped]
    end

    sig { params(package: Packwerk::Package, filepath: String).void }
    def initialize(package, filepath)
      @package = package
      @filepath = filepath
      @new_entries = T.let({}, EntriesType)
      @todo_list = T.let(nil, T.nilable(EntriesType))
    end

    sig do
      params(reference: Packwerk::Reference, violation_type: ViolationType)
        .returns(T::Boolean)
    end
    def listed?(reference, violation_type:)
      violated_constants_found = todo_list.dig(reference.constant.package.name, reference.constant.name)
      return false unless violated_constants_found

      violated_constant_in_file = violated_constants_found.fetch("files", []).include?(reference.relative_path)
      return false unless violated_constant_in_file

      violated_constants_found.fetch("violations", []).include?(violation_type.serialize)
    end

    sig { params(reference: Packwerk::Reference, violation_type: Packwerk::ViolationType).returns(T::Boolean) }
    def add_entries(reference, violation_type)
      package_violations = @new_entries.fetch(reference.constant.package.name, {})
      entries_for_constant = package_violations[reference.constant.name] ||= {}

      entries_for_constant["violations"] ||= []
      entries_for_constant["violations"] << violation_type.serialize

      entries_for_constant["files"] ||= []
      entries_for_constant["files"] << reference.relative_path.to_s

      @new_entries[reference.constant.package.name] = package_violations
      listed?(reference, violation_type: violation_type)
    end

    sig { params(for_files: T::Set[String]).returns(T::Boolean) }
    def stale_violations?(for_files)
      prepare_entries_for_dump

      todo_list.any? do |package, package_violations|
        package_violations_for_files = {}
        package_violations.each do |constant_name, entries_for_constant|
          entries_for_files = for_files & entries_for_constant["files"]
          next if entries_for_files.none?

          package_violations_for_files[constant_name] = {
            "violations" => entries_for_constant["violations"],
            "files" => entries_for_files.to_a,
          }
        end

        return true if package_violations_for_files.empty?

        package_violations_for_files.any? do |constant_name, entries_for_constant|
          new_entries_violation_types = @new_entries.dig(package, constant_name, "violations")
          return true if new_entries_violation_types.nil?

          if entries_for_constant["violations"].all? { |type| new_entries_violation_types.include?(type) }
            stale_violations =
              entries_for_constant["files"] - Array(@new_entries.dig(package, constant_name, "files"))
            stale_violations.any?
          else
            return true
          end
        end
      end
    end

    sig { void }
    def dump
      delete_old_deprecated_references

      if @new_entries.empty?
        delete_if_exists
      else
        prepare_entries_for_dump
        message = <<~MESSAGE
          # This file contains a list of dependencies that are not part of the long term plan for #{@package.name}.
          # We should generally work to reduce this list, but not at the expense of actually getting work done.
          #
          # You can regenerate this file using the following command:
          #
          # bin/packwerk update-todo #{@package.name}
        MESSAGE
        package_todo_filepath = File.join(File.dirname(@filepath), "package_todo.yml")

        File.open(package_todo_filepath, "w") do |f|
          f.write(message)
          f.write(@new_entries.to_yaml)
        end
      end
    end

    sig { void }
    def delete_if_exists
      File.delete(@filepath) if File.exist?(@filepath)
    end

    private

    sig { void }
    def delete_old_deprecated_references
      deprecated_references_filepath = File.join(File.dirname(@filepath), "deprecated_references.yml")
      File.delete(deprecated_references_filepath) if File.exist?(deprecated_references_filepath)
    end

    sig { returns(EntriesType) }
    def prepare_entries_for_dump
      @new_entries.each do |package_name, package_violations|
        package_violations.each do |_, entries_for_constant|
          entries_for_constant["violations"].sort!.uniq!
          entries_for_constant["files"].sort!.uniq!
        end
        @new_entries[package_name] = package_violations.sort.to_h
      end

      @new_entries = @new_entries.sort.to_h
    end

    sig { returns(EntriesType) }
    def todo_list
      @todo_list ||= if File.exist?(@filepath)
        load_yaml(@filepath)
      else
        {}
      end
    end

    sig { params(filepath: String).returns(EntriesType) }
    def load_yaml(filepath)
      YAML.load_file(filepath) || {}
    rescue Psych::Exception
      {}
    end
  end
end
