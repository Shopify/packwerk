# typed: true
# frozen_string_literal: true

require "rails"

class Dummy < Rails::Application
  class << self
    def skeleton(*path)
      ROOT.join("test", "fixtures", "skeleton", *path).to_s
    end
  end

  config.autoloader = :zeitwerk
  config.eager_load = false
  config.eager_load_paths    = [skeleton("components", "platform", "app", "models")]
  config.autoload_paths      = [skeleton("components", "sales", "app", "models")]
  config.autoload_once_paths = [
    skeleton("components", "timeline", "app", "models"),
    skeleton("components", "timeline", "app", "models", "concerns"),
    skeleton("vendor", "cache", "gems", "example", "models"),
  ]
  config.root = skeleton(".")
  config.logger = Logger.new("/dev/null")
end

Rails.application.initialize!
