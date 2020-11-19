# typed: true
# frozen_string_literal: true

module Packwerk
  class GenerateConfigsCommand
    extend T::Sig
    Result = Struct.new(:message, :status)

    def initialize(out:, configuration:)
      @out = out
      @configuration = configuration
    end

    sig { returns(Result) }
    def run
      configuration_file = Packwerk::Generators::ConfigurationFile.generate(
        load_paths: @configuration.load_paths,
        root: @configuration.root_path,
        out: @out
      )
      inflections_file = Packwerk::Generators::InflectionsFile.generate(root: @configuration.root_path, out: @out)
      root_package = Packwerk::Generators::RootPackage.generate(root: @configuration.root_path, out: @out)

      @success = configuration_file && inflections_file && root_package

      result = calculate_result
      @out.puts(result.message)
      result
    end

    private

    sig { returns Result }
    def calculate_result
      message = if @success
        <<~EOS

          🎉 Packwerk is ready to be used. You can start defining packages and run `packwerk check`.
          For more information on how to use Packwerk, see: https://github.com/Shopify/packwerk/blob/main/USAGE.md
        EOS
      else
        <<~EOS

          ⚠️  Packwerk is not ready to be used.
          Please check output and refer to https://github.com/Shopify/packwerk/blob/main/USAGE.md for more information.
        EOS
      end

      Result.new(message, @success)
    end
  end
end
