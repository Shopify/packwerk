# typed: ignore
# frozen_string_literal: true

require "rails_test_helper"

module FixtureHelper
  TEMP_FIXTURE_DIR = ROOT.join("tmp", "fixtures").to_s
  FileUtils.mkdir_p(TEMP_FIXTURE_DIR)

  Minitest.after_run do
    # This does not get called on early exit, e.g. `Ctrl-C` or `(byebug) exit`.
    FileUtils.remove_entry(TEMP_FIXTURE_DIR, true)
  end

  def around
    old_working_dir = Dir.pwd
    cache_rails_paths

    yield

    restore_rails_paths
    Dir.chdir(old_working_dir)
    FileUtils.remove_entry(@app_dir, true) if defined? @app_dir
  end

  def copy_template(template)
    copy_dir("test/fixtures/#{template}")
    Dir.chdir(app_dir)

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

  def copy_dir(path)
    root = Dir.mktmpdir(self.name, TEMP_FIXTURE_DIR)
    FileUtils.cp_r("#{path}/.", root)
    @app_dir = root
  end

  def config
    @config ||= Packwerk::Configuration.from_path(app_dir)
  end

  def merge_into_yaml_file(relative_path, hash)
    path = path_to(relative_path)
    FileUtils.mkpath(File.dirname(path))
    FileUtils.touch(path)
    data = YAML.load_file(path) || {}
    recursive_merge!(data, hash)
    File.open(path, 'w') { |f| YAML.dump(data, f) }
  end

  def remove_app_entry(relative_path)
    FileUtils.remove_entry(path_to(relative_path))
  end

  def path_to(relative_path)
    File.join(app_dir, relative_path)
  end

  def paths_to(*relative_paths)
    relative_paths.map { |path| path_to(path) }
  end

  def app_dir
    copy_template(:minimal) unless defined? @app_dir
    @app_dir
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

  def recursive_merge!(hash, other_hash)
    hash.merge!(other_hash) do |_, old_value, new_value|
      if old_value.is_a?(Hash) && new_value.is_a?(Hash)
        recursive_merge!(old_value, new_value)
      elsif old_value.is_a?(Array)
        old_value + Array(new_value)
      else
        new_value
      end
    end
  end
end
