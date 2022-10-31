# typed: strict
# frozen_string_literal: true

module Packwerk
  module ReferenceChecking
    module Checkers
      # Checks whether a given reference conforms to the configured graph of dependencies.
      class DependencyChecker
        extend T::Sig
        include Checker

        VIOLATION_TYPE = T.let("dependency", String)

        sig { override.returns(String) }
        def violation_type
          VIOLATION_TYPE
        end

        sig do
          override
            .params(reference: Packwerk::Reference)
            .returns(T::Boolean)
        end
        def invalid_reference?(reference)
          return false unless reference.source_package
          return false unless reference.source_package.enforce_dependencies?
          return false if reference.source_package.dependency?(reference.constant.package)

          true
        end

        sig do
          override
            .params(reference: Packwerk::Reference)
            .returns(String)
        end
        def message(reference)
          <<~EOS
            Dependency violation: #{reference.constant.name} belongs to '#{reference.constant.package}', but '#{reference.source_package}' does not specify a dependency on '#{reference.constant.package}'.
            Are we missing an abstraction?
            Is the code making the reference, and the referenced constant, in the right packages?

            #{standard_help_message(reference)}
          EOS
        end

        private

        sig { params(reference: Reference).returns(String) }
        def standard_help_message(reference)
          standard_message = <<~EOS.chomp
            Inference details: this is a reference to #{reference.constant.name} which seems to be defined in #{reference.constant.location}.
            To receive help interpreting or resolving this error message, see: https://github.com/Shopify/packwerk/blob/main/TROUBLESHOOT.md#Troubleshooting-violations
          EOS

          standard_message.chomp
        end
      end
    end
  end
end
