# typed: strict
# frozen_string_literal: true

module Packwerk
  module Commands
    class Init < Command
      extend T::Sig


      sig { returns(T::Boolean) }
      def init
        say("📦 Initializing Packwerk...")

        generate_configs
      end

      private

      sig { returns(T::Boolean) }
    def generate_configs
        configuration_file = Generators::ConfigurationFile.generate(
          root: @configuration.root_path,
          shell: shell
        )

        root_package = Generators::RootPackage.generate(root: @configuration.root_path, shell: shell)

        success = configuration_file && root_package

        result = if success
          <<~EOS
            🎉 Packwerk is ready to be used. You can start defining packages and run `bin/packwerk check`.
            For more information on how to use Packwerk, see: https://github.com/Shopify/packwerk/blob/main/USAGE.md
          EOS
        else
          <<~EOS
            ⚠️  Packwerk is not ready to be used.
            Please check output and refer to https://github.com/Shopify/packwerk/blob/main/USAGE.md for more information.
          EOS
        end

        say(result)
        success
      end
    end
  end
end
