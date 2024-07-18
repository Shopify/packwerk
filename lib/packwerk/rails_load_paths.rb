# typed: strict
# frozen_string_literal: true

require "bundler"
gem "railties", ">= 6.0"
require "rails/railtie"

module Packwerk
  # Extracts the load paths from the analyzed application so that we can map constant names to paths.
  module RailsLoadPaths
    class << self
      extend T::Sig

      sig { params(root: String, environment: String).returns(T::Enumerable[Zeitwerk::Loader]) }
      def loaders_for(root, environment:)
        require_application(root, environment)
        Rails.autoloaders
      end

      private

      sig { params(root: String, environment: String).void }
      def require_application(root, environment)
        environment_file = "#{root}/config/environment"

        if File.file?("#{environment_file}.rb")
          ENV["RAILS_ENV"] ||= environment

          require environment_file
        else
          raise "A Rails application could not be found in #{root}"
        end
      end
    end
  end
end
