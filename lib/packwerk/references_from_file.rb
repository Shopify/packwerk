# typed: false
# frozen_string_literal: true

module Packwerk
    # Extracts all static constant references between Ruby files.
    # Reuses the packwerk configuration.
    # Hackishly hooks into packwerk internals.
    class ReferencesFromFile
      def initialize(config = Configuration.from_path)
        @config = config
        # RunContext is a `private_constant` of `Packwerk`
        @run_context = RunContext.from_configuration(@config)
      end
  
      def list_all(relative_file_paths: [])
        # FilesForProcessing is a `private_constant` of `Packwerk`
        files = FilesForProcessing.fetch(relative_file_paths:, configuration: @config).files
  
        files.map { |file| list(file) }.flatten(1)
      end
  
      def list(relative_file)
        file_processor = @run_context.send(:file_processor)
        context_provider = @run_context.send(:context_provider)
  
        unresolved_references = file_processor.call(relative_file).unresolved_references
  
        # ReferenceExtractor is a `private_constant` of `Packwerk`
        ReferenceExtractor.get_fully_qualified_references_from(
          unresolved_references,
          context_provider
        )
      end
    end
  end