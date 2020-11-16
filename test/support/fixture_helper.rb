# typed: ignore
# frozen_string_literal: true

module FixtureHelper
  TEMP_FIXTURE_DIR = ROOT.join("tmp", "fixtures").to_s

  def setup_fixture
    @old_working_dir = Dir.pwd
  end

  def teardown_fixture
    Dir.chdir(@old_working_dir)
    FileUtils.remove_entry(@app_dir, true) if defined? @app_dir
  end

  # def around
  #   old_working_dir = Dir.pwd
  #   yield
  # ensure
  #   Dir.chdir(old_working_dir)
  #   FileUtils.remove_entry(@app_dir, true) if defined? @app_dir
  # end

  def copy_template(template)
    copy_dir("test/fixtures/#{template}")
    Dir.chdir(app_dir)
  end

  def copy_dir(path)
    root = FileUtils.mkdir_p(fixture_path).last
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

  def fixture_path
    File.join(TEMP_FIXTURE_DIR, "#{name}-#{Time.now.strftime("%Y%m%d")}")
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
