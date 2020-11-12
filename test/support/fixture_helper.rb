# typed: ignore
# frozen_string_literal: true

module FixtureHelper
  TEMP_FIXTURE_DIR = ROOT.join("tmp", "fixtures").to_s
  FileUtils.mkdir_p(TEMP_FIXTURE_DIR)

  Minitest.after_run do
    # This does not get called on early exit, e.g. `Ctrl-C` or `(byebug) exit`.
    FileUtils.remove_entry(TEMP_FIXTURE_DIR, true)
  end

  def around
    old_working_dir = Dir.pwd

    yield

    Dir.chdir(old_working_dir)
    FileUtils.remove_entry(@app_dir, true) if defined? @app_dir
  end

  def copy_template(template)
    copy_dir("test/fixtures/#{template}")
    Dir.chdir(app_dir)
  end

  def copy_dir(path)
    root = Dir.mktmpdir(name, TEMP_FIXTURE_DIR)
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
    File.open(path, "w") { |f| YAML.dump(data, f) }
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
