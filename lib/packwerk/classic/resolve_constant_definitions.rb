# typed: false
# frozen_string_literal: true

require "constant_resolver"

module Packwerk
  module Classic
    class ResolveConstantDefinitions
      extend T::Sig

      def initialize(configuration:)
        @configuration = configuration
        @inflector = ::Packwerk::Inflector.from_file(configuration.inflections_file)
        @resolver = ConstantResolver.new(
          root_path: @configuration.root_path.to_s,
          load_paths: @configuration.load_paths,
          inflector: @inflector
        )
        @parser_factory = Packwerk::Parsers::Factory.instance
      end

      def collect_file_offenses(file_path)
        parser = @parser_factory.for_path(file_path)
        return [FileProcessor::UnknownFileTypeResult.new(file: file_path)] if parser.nil?

        node = File.open(file_path, "r", external_encoding: Encoding::UTF_8) do |file|
          parser.call(io: file, file_path: file_path)
        rescue Parsers::ParseError => e
          return [e.result]
        end

        result = []
        if node
          constant_definitions = ExtractAutoloadableConstantDefinitions.new(
            root_node: node,
            file: file_path,
            inflector: @inflector
          ).constant_definitions
          result += collect_resolution_offenses(constant_definitions, file: file_path)
        end
        result.compact
      end

      private

      def collect_resolution_offenses(constant_definitions, file:)
        constant_definitions.map do |constant, location|
          context = @resolver.resolve(constant)
          extract_resolution_offense(constant, context, file: file, location: location)
        end
      end

      def extract_resolution_offense(constant, context, file:, location:)
        actual_context_location = Pathname.new(file).relative_path_from(@configuration.root_path).to_s
        if context.nil?
          message = <<~EOS
            #{constant} is defined in #{actual_context_location} but cannot be resolved by Zeitwerk.
            Please verify that the load path for #{constant} is correct and doesn't contain a missing inflection.
          EOS
          Offense.new(file: file, message: message, location: location)
        elsif actual_context_location != context.location
          message = <<~EOS
            Expected #{constant} to be defined in #{context.location},
            but found a definition in #{actual_context_location}.
            Please verify that the load path for #{constant} is correct.
          EOS
          Offense.new(file: file, message: message, location: location)
        end
      end
    end
  end
end
