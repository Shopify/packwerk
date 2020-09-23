# typed: true
# frozen_string_literal: true

module Packwerk
  module Generators
    class InflectionsFile
      extend T::Sig

      class << self
        def generate(root:, out:)
          new(root, out: out).generate
        end
      end

      def initialize(root, out: $stdout)
        @root = root
        @out = out
      end

      sig { returns(T::Boolean) }
      def generate
        ruby_inflection_file_exist = Dir.glob("#{@root}/**/inflections.rb").any?
        yaml_inflection_file_exist = Dir.glob("#{@root}/**/inflections.yml").any?

        if !ruby_inflection_file_exist || yaml_inflection_file_exist
          return true
        end

        @out.puts("📦 Generating `inflections.yml` file...")

        destination_file_path = File.join(@root, "config")
        FileUtils.mkdir_p(destination_file_path)

        source_file_path = File.join(__dir__, "/templates/inflections.yml")
        FileUtils.cp(source_file_path, destination_file_path)

        @out.puts("✅ `inflections.yml` generated in #{destination_file_path}")

        true
      end
    end
  end
end
