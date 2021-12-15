# typed: strict
# frozen_string_literal: true

module Packwerk
  module RailsDependencies
    class Load
      extend T::Sig

      sig { returns(Result) }
      def self.load_from_file!
        require 'pry'
        dump_path = Pathname.new(DUMP_FILE)
        raw_file_contents = dump_path.read
        # Once we read the contents, we can clean this file up
        dump_path.delete
        parsed_file_contents = YAML.load(raw_file_contents);
        inflector = Inflector.new(parsed_file_contents[:inflections])
        Result.new(load_paths: parsed_file_contents[:load_paths], inflector: inflector)
      end

      # This is a fallback if someone does not have a `bin/rake` file.
      sig { params(root_path: String, environment: String).returns(Result) }
      def self.load_from_rails_directly!(root_path, environment)
        require_application(root_path, environment)
        load_paths = ApplicationLoadPaths.extract_relevant_paths("test")
        inflections = ActiveSupport::Inflector.inflections

        Result.new(
          load_paths: load_paths,
          inflector: Inflector.new(inflections)
        )
      end

      sig { params(root: String, environment: String).void }
      def self.require_application(root, environment)
        environment_file = "#{root}/config/environment"

        if File.file?("#{environment_file}.rb")
          ENV["RAILS_ENV"] ||= environment

          require environment_file
        else
          raise "A Rails application could not be found in #{root}"
        end
      end

      private_class_method :require_application
    end
  end
end
