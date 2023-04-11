# typed: strict
# frozen_string_literal: true

module Packwerk
  module Commands
    class Validate < Command
      extend T::Sig

      class << self
        extend T::Sig

        sig { returns(String) }
        def description
          "verify integrity of packwerk and package configuration"
        end
      end

      sig { returns(T::Boolean) }
      def validate
        result = T.let(nil, T.nilable(Validator::Result))

        shell.progress_formatter.started_validation do
          result = validator.check_all(package_set, configuration)

          list_validation_errors(result)
        end

        T.must(result).ok?
      end

      private

      sig { params(result: Validator::Result).void }
      def list_validation_errors(result)
        say
        if result.ok?
          say("Validation successful 🎉")
        else
          say("Validation failed ❗")
          say
          say(result.error_value)
        end
      end

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
    end
  end
end
