# typed: strict
# frozen_string_literal: true

module Packwerk
  class Cli
    class InitCommand < BaseCommand
      extend T::Sig

      register_cli_command "init"

      sig { override.returns(Result) }
      def run
        cli.out.puts("📦 Initializing Packwerk...")

        configuration_file = Generators::ConfigurationFile.generate(
          root: cli.configuration.root_path,
          out: cli.out
        )

        root_package = Generators::RootPackage.generate(root: cli.configuration.root_path, out: @cli.out)

        success = configuration_file && root_package

        message = if success
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

        Result.new(message: message, status: success)
      end
    end

    private_constant :InitCommand
  end
end
