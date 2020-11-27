# typed: false
# frozen_string_literal: true

require "rails_test_helper"

module RailsApplicationFixtureHelper
  include ApplicationFixtureHelper

  def setup_application_fixture
    super()
    cache_rails_paths
  end

  def teardown_application_fixture
    restore_rails_paths
    super()
  end

  def use_template(template)
    super(template)

    case template
    when :minimal
      set_load_paths_for_minimal_template
    when :skeleton
      set_load_paths_for_skeleton_template
    else
      raise "Unknown fixture template #{template}"
    end

    RailsPaths.root(app_dir)
  end

  private

  def set_load_paths_for_minimal_template
    RailsPaths.autoload(to_app_paths("/components/sales/app/models"))
    RailsPaths.eager_load([])
    RailsPaths.autoload_once([])
  end

  def set_load_paths_for_skeleton_template
    RailsPaths.autoload(to_app_paths("/components/sales/app/models"))
    RailsPaths.eager_load(to_app_paths("components/platform/app/models"))
    RailsPaths.autoload_once(
      to_app_paths(
        "components/timeline/app/models",
        "components/timeline/app/models/concerns",
        "vendor/cache/gems/example/models",
      )
    )
  end

  def cache_rails_paths
    raise "cache_rails_paths may only be called once per test" if defined? @rails_paths
    @rails_paths = RailsPaths.new
    @rails_paths.cache
  end

  def restore_rails_paths
    @rails_paths.restore
  end
end
