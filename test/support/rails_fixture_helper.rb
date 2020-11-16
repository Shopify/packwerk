# typed: ignore
# frozen_string_literal: true

require "rails_test_helper"

module RailsFixtureHelper
  include FixtureHelper

  def setup_fixture
    super()
    cache_rails_paths
  end

  def teardown_fixture
    restore_rails_paths
    super()
  end

  # def around
  #   super do
  #     cache_rails_paths

  #     yield

  #     restore_rails_paths
  #   end
  # end

  def copy_template(template)
    super(template)

    case template
    when :minimal
      rails_autoload_paths(paths_to("/components/sales/app/models"))
      rails_eager_load_paths([])
      rails_autoload_once_paths([])
      rails_root_path(app_dir)
    when :skeleton
      rails_autoload_paths(paths_to("components/sales/app/models"))
      rails_eager_load_paths(paths_to("components/platform/app/models"))
      rails_autoload_once_paths(
        paths_to(
          "components/timeline/app/models",
          "components/timeline/app/models/concerns",
          "vendor/cache/gems/example/models",
        )
      )
      rails_root_path(app_dir)
      # make sure PrivateThing.constantize succeeds to pass the privacy validity check
      require "fixtures/skeleton/components/timeline/app/models/private_thing.rb"
    else
      raise "Unknown fixture template #{template}"
    end
  end

  private

  def rails_autoload_paths(paths)
    Rails.application.config.autoload_paths = paths
  end

  def rails_eager_load_paths(paths)
    Rails.application.config.eager_load_paths = paths
  end

  def rails_autoload_once_paths(paths)
    Rails.application.config.autoload_once_paths = paths
  end

  def rails_root_path(path)
    Rails.application.config.root = path
  end

  def cache_rails_paths
    @rails_autoload_paths = Rails.application.config.autoload_paths
    @rails_eager_load_paths = Rails.application.config.eager_load_paths
    @rails_autoload_once_paths = Rails.application.config.autoload_once_paths
    @rails_root_path = Rails.application.config.root
  end

  def restore_rails_paths
    rails_autoload_paths(@rails_autoload_paths)
    rails_eager_load_paths(@rails_eager_load_paths)
    rails_autoload_once_paths(@rails_autoload_once_paths)
    rails_root_path(@rails_root_path)
  end
end
