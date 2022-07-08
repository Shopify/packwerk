# typed: strict
# frozen_string_literal: true

module Packwerk
  module ReferenceChecking
    module Checkers
      # Checks whether a given reference conforms to the configured graph of dependencies.
      class DependencyChecker
        extend T::Sig
        include Checker

        sig { override.returns(ViolationType) }
        def violation_type
          ViolationType::Dependency
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
      end
    end
  end
end
