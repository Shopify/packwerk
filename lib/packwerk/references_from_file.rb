# typed: strict
# frozen_string_literal: true

module Packwerk
  # Extracts all static constant references between Ruby files.
  class ReferencesFromFile
    extend T::Sig

    class FileParserError < RuntimeError
      extend T::Sig

      sig { params(file: String, offenses: T::Array[Packwerk::Offense]).void }
      def initialize(file:, offenses:)
        super("Errors while parsing #{file}: #{offenses.map(&:to_s).join("\n")}")
      end
    end

    sig { params(config: Packwerk::Configuration).void }
    def initialize(config = Configuration.from_path)
      @config = config
      @run_context = T.let(RunContext.from_configuration(@config), RunContext)
    end

    sig { params(relative_file_paths: T::Array[String]).returns(T::Array[Packwerk::Reference]) }
    def list_for_all(relative_file_paths: [])
      files = FilesForProcessing.fetch(relative_file_paths: relative_file_paths, configuration: @config).files
      files.flat_map { |file| list_for_file(file) }
    end

    sig { params(relative_file: String).returns(T::Array[Packwerk::Reference]) }
    def list_for_file(relative_file)
      references_result = @run_context.references_from_file(relative_file: relative_file)

      if references_result.file_offenses.present?
        raise FileParserError.new(file: relative_file, offenses: references_result.file_offenses)
      end

      references_result.references
    end
  end
end
