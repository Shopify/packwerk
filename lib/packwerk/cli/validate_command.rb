# typed: strict
# frozen_string_literal: true

module Packwerk
  class Cli
    class ValidateCommand
      extend T::Sig

      sig do
        params(
          out: T.any(StringIO, IO),
          configuration: Configuration,
          progress_formatter: Formatters::ProgressFormatter,
        ).void
      end
      def initialize(out:, configuration:, progress_formatter:)
        @out = out
        @configuration = configuration
        @progress_formatter = progress_formatter
      end

      sig { returns(T::Boolean) }
      def run
        result = T.let(nil, T.nilable(Validator::Result))

        @progress_formatter.started_validation do
          result = validator.check_all(package_set, @configuration)

          list_validation_errors(result)
        end

        T.must(result).ok?
      end

      private

      sig { returns(ApplicationValidator) }
      def validator
        ApplicationValidator.new
      end

      sig { returns(PackageSet) }
      def package_set
        PackageSet.load_all_from(
          @configuration.root_path,
          package_pathspec: @configuration.package_paths
        )
      end

      sig { params(result: Validator::Result).void }
      def list_validation_errors(result)
        @out.puts
        if result.ok?
          @out.puts("Validation successful 🎉")
        else
          @out.puts("Validation failed ❗")
          @out.puts
          @out.puts(result.error_value)
        end
      end
    end

    private_constant :ValidateCommand
  end
end
