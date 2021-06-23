# typed: false
# frozen_string_literal: true

module Packwerk
  module Classic
    autoload :ZeitwerkValidationRun, "packwerk/classic/zeitwerk_validation_run"
    autoload :ResolveConstantDefinitions, "packwerk/classic/resolve_constant_definitions"
    autoload :ExtractAutoloadableConstantDefinitions, "packwerk/classic/extract_autoloadable_constant_definitions"
  end
end
