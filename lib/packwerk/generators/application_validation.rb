# typed: true
# frozen_string_literal: true

module Packwerk
  module Generators
    class ApplicationValidation
      class << self
        def generate(for_rails_app: false, root: ".", out: $stdout)
          new(root, out: out).generate(for_rails_app: for_rails_app)
        end
      end

      def initialize(root, out: $stdout)
        @root = root
        @out = out
      end

      def generate(for_rails_app:)
        @out.puts("📦 Generating application validator...")
        if for_rails_app
          generate_packwerk_validate_script
        else
          generate_validation_test
        end
      end

      private

      def generate_packwerk_validate_script
        destination_file_path = File.join(@root, "bin")
        FileUtils.mkdir_p(destination_file_path)

        if File.exist?(File.join(destination_file_path, "packwerk"))
          @out.puts("⚠️  Packwerk application validation bin script already exists.")
          return true
        end

        source_file_path = File.expand_path("../templates/packwerk", __FILE__)
        FileUtils.cp(source_file_path, destination_file_path)

        @out.puts("✅ Packwerk application validation bin script generated in #{destination_file_path}")
        true
      end

      def generate_validation_test
        destination_file_path = File.join(@root, "test")
        FileUtils.mkdir_p(destination_file_path)

        if File.exist?(File.join(destination_file_path, "packwerk_validator_test.rb"))
          @out.puts("⚠️  Packwerk application validation test already exists.")
          return true
        end

        source_file_path = File.expand_path("../templates/packwerk_validator_test.rb", __FILE__)
        FileUtils.cp(source_file_path, destination_file_path)

        @out.puts("✅ Packwerk application validation test generated in #{destination_file_path}")
        true
      end
    end
  end
end
