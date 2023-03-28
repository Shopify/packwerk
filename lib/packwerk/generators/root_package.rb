# typed: strict
# frozen_string_literal: true

module Packwerk
  module Generators
    class RootPackage
      extend T::Sig

      class << self
        extend T::Sig

        sig { params(root: String, shell: Shell).returns(T::Boolean) }
        def generate(root:, shell:)
          new(root: root, shell: shell).generate
        end
      end

      sig { params(root: String, shell: Shell).void }
      def initialize(root:, shell:)
        @root = root
        @shell = shell
      end

      sig { returns(T::Boolean) }
      def generate
        if Dir.glob("#{@root}/package.yml").any?
          @shell.say("⚠️  Root package already exists.")
          return true
        end

        @shell.say("📦 Generating `package.yml` file for root package...")

        source_file_path = File.join(__dir__, "/templates/package.yml")
        FileUtils.cp(source_file_path, @root)

        @shell.say("✅ `package.yml` for the root package generated in #{@root}")
        true
      end
    end
  end
end
