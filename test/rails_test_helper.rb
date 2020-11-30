# typed: false
# frozen_string_literal: true

require "rails"

class Dummy < Rails::Application
  def self.skeleton(*path)
    ROOT.join("test", "fixtures", "skeleton", *path).to_s
  end

  config.eager_load_paths    = [skeleton("components", "platform", "app", "models")]
  config.autoload_paths      = [skeleton("components", "sales", "app", "models")]
  config.autoload_once_paths = [
    skeleton("components", "timeline", "app", "models"),
    skeleton("components", "timeline", "app", "models", "concerns"),
    skeleton("vendor", "cache", "gems", "example", "models"),
  ]
  config.root = skeleton(".")
end
