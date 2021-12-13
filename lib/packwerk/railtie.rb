require 'packwerk'
require 'rails'

module Packwerk
  class Railtie < Rails::Railtie
    railtie_name :packwerk

    rake_tasks do
      path = File.expand_path(__dir__)
      load "packwerk/rails_dependencies/dump.rake"
    end
  end
end
