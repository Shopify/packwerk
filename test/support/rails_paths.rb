# typed: false
# frozen_string_literal: true

class RailsPaths
  class << self
    def autoload(paths)
      Rails.application.config.autoload_paths = paths
    end

    def eager_load(paths)
      Rails.application.config.eager_load_paths = paths
    end

    def autoload_once(paths)
      Rails.application.config.autoload_once_paths = paths
    end

    def root(path)
      Rails.application.config.root = path
    end
  end

  def cache
    @autoload_paths = Rails.application.config.autoload_paths
    @eager_load_paths = Rails.application.config.eager_load_paths
    @autoload_once_paths = Rails.application.config.autoload_once_paths
    @root_path = Rails.application.config.root
  end

  def restore
    self.class.autoload(@autoload_paths)
    self.class.eager_load(@eager_load_paths)
    self.class.autoload_once(@autoload_once_paths)
    self.class.root(@root_path)
  end
end
