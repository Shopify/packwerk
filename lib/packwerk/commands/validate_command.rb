# typed: true
# frozen_string_literal: true

module Packwerk
  class ValidateCommand
    extend T::Sig

    def initialize(out:, configuration:, progress_formatter:)
      @out = out
      @configuration = configuration
      @progress_formatter = progress_formatter
    end

    sig { returns(T::Boolean) }
    def run
      warn("`packwerk validate` should be run within the application. "\
        "Generate the bin script using `packwerk init` and"\
        " use `bin/packwerk validate` instead.") unless defined?(::Rails)

      @progress_formatter.started_validation do
        checker = Packwerk::ApplicationValidator.new(
          config_file_path: @configuration.config_path,
          configuration: @configuration
        )
        result = checker.check_all

        list_validation_errors(result)

        return result.ok?
      end
    end

    private

    def list_validation_errors(result)
      @out.puts
      if result.ok?
        @out.puts("Validation successful 🎉")
      else
        @out.puts("Validation failed ❗")
        @out.puts(result.error_value)
      end
    end
  end
end
