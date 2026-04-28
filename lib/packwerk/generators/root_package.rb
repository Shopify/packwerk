# typed: strict
# frozen_string_literal: true

module Packwerk
  module Generators
    class RootPackage
      extend T::Sig

      class << self
        extend T::Sig

        #: (root: String, out: (IO | StringIO)) -> bool
        def generate(root:, out:)
          new(root: root, out: out).generate
        end
      end

      #: (root: String, ?out: (IO | StringIO)) -> void
      def initialize(root:, out: $stdout)
        @root = root
        @out = out
      end

      #: -> bool
      def generate
        if Dir.glob("#{@root}/package.yml").any?
          @out.puts("⚠️  Root package already exists.")
          return true
        end

        @out.puts("📦 Generating `package.yml` file for root package...")

        source_file_path = File.join(__dir__, "/templates/package.yml")
        FileUtils.cp(source_file_path, @root)

        @out.puts("✅ `package.yml` for the root package generated in #{@root}")
        true
      end
    end
  end
end
