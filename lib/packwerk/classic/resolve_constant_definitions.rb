# typed: false
# frozen_string_literal: true

require "constant_resolver"

module Packwerk
  module Classic
    class ResolveConstantDefinitions
      extend T::Sig

      def initialize(
        configuration:,
        progress_formatter: Formatters::ProgressFormatter.new(StringIO.new),
        offenses_formatter: Formatters::OffensesFormatter.new
      )
        @configuration = configuration
        @progress_formatter = progress_formatter
        @offenses_formatter = offenses_formatter
        @inflector = ::Packwerk::Inflector.from_file(configuration.inflections_file)
        @resolver = ConstantResolver.new(
          root_path: @configuration.root_path.to_s,
          load_paths: @configuration.load_paths,
          inflector: @inflector
        )
        @parser_factory = Packwerk::Parsers::Factory.instance
      end

      def call
        file_paths = autoloadable_file_paths
        file_paths.map { |file_path| collect_file_offenses(file_path) }.flatten.compact
      end

      private

      def autoloadable_file_paths
        root_path = Pathname.new(@configuration.root_path)
        @configuration.load_paths.map do |load_path|
          Dir.glob(File.join(root_path, load_path, "**", "*.rb"))
        end.flatten
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
          constant_definitions = ExtractConstantDefinitions.new(root_node: node).constant_definitions
          result += collect_resolution_offenses(constant_definitions, file: file_path)
        end
        result
      end

      def collect_resolution_offenses(constant_definitions, file:)
        constant_definitions.map do |constant, location|
          context = @resolver.resolve(constant)
          extract_resolution_offense(constant, context, file: file, location: location)
        end
      end

      def extract_resolution_offense(constant, context, file:, location:)
        actual_context_location = Pathname.new(file).relative_path_from(@configuration.root_path).to_s
        if context.nil?
          message = "cannot resolve #{constant} defined in #{actual_context_location}"
          Offense.new(file: file, message: message, location: location)
        elsif actual_context_location != context.location
          message = "expected #{constant} to be defined in #{context.location}"
          Offense.new(file: file, message: message, location: location)
        end
      end
    end
  end
end
