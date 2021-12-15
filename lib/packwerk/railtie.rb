# frozen_string_literal: true
require "packwerk"
require "rails"

module Packwerk
  class Railtie < Rails::Railtie
    railtie_name :packwerk

    rake_tasks do
      load "packwerk/rails_dependencies/dump.rake"
    end
  end
end
