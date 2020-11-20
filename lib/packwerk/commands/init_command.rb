# typed: true
# frozen_string_literal: true

module Packwerk
  class InitCommand
    extend T::Sig

    def initialize(out:, configuration:)
      @out = out
      @configuration = configuration
    end

    sig { returns(T::Boolean) }
    def run
      @out.puts("📦 Initializing Packwerk...")

      application_validation = Packwerk::Generators::ApplicationValidation.generate(
        for_rails_app: rails_app?,
        root: @configuration.root_path,
        out: @out
      )

      if application_validation
        if rails_app?
          # To run in the same space as the Rails process,
          # in order to fetch load paths for the configuration generator
          exec("bin/packwerk", "generate_configs")
        else
          generate_configurations = generate_configs
        end
      end

      application_validation && generate_configurations
    end

    private

    sig { returns(T::Boolean) }
    def rails_app?
      if File.exist?("config/application.rb") && File.exist?("bin/rails")
        File.foreach("Gemfile").any? { |line| line.match?(/['"]rails['"]/) }
      else
        false
      end
    end

    sig { returns(T::Boolean) }
    def generate_configs
      GenerateConfigsCommand.new(out: @out, configuration: @configuration).run
    end
  end
end
