# typed: true
# frozen_string_literal: true

module ApplicationFixtureHelper
  TEMP_FIXTURE_DIR = ROOT.join("tmp", "fixtures").to_s
  DEFAULT_TEMPLATE = :minimal

  extend T::Helpers

  requires_ancestor { Kernel }

  def setup_application_fixture
    @old_working_dir = Dir.pwd
  end

  def teardown_application_fixture
    Dir.chdir(@old_working_dir)
    FileUtils.remove_entry(@app_dir, true) if using_template?
  end

  def use_template(template)
    raise "use_template may only be called once per test" if using_template?

    copy_dir("test/fixtures/#{template}")
    Dir.chdir(app_dir)
  end

  def app_dir
    unless using_template?
      raise "You need to set up an application fixture by calling `use_template(:the_template)`."
    end

    @app_dir
  end

  def config
    @config ||= Packwerk::Configuration.from_path(app_dir)
  end

  def package_set
    @package_set ||= Packwerk::PackageSet.load_all_from(config.root_path)
  end

  def to_app_path(relative_path)
    File.join(app_dir, relative_path)
  end

  def to_app_paths(*relative_paths)
    relative_paths.map { |path| to_app_path(path) }
  end

  def merge_into_app_yaml_file(relative_path, hash)
    path = to_app_path(relative_path)
    YamlFile.new(path).merge(hash)
  end

  def remove_app_entry(relative_path)
    FileUtils.remove_entry(to_app_path(relative_path))
  end

  def open_app_file(path, mode: "w+", &block)
    expanded_path = to_app_path(File.join(path))
    File.open(expanded_path, mode, &block)
  end

  # This gets cleaned up by `teardown_application_fixture`
  def write_app_file(path, content)
    expanded_path = to_app_path(File.join(*path))
    FileUtils.mkdir_p(Pathname.new(expanded_path).dirname)
    File.open(expanded_path, "w+") do |file|
      file.write(content)
      file.flush
    end
  end

  private

  def using_template?
    defined? @app_dir
  end

  def copy_dir(path)
    root = FileUtils.mkdir_p(fixture_path).last
    FileUtils.cp_r("#{path}/.", T.must(root))
    @app_dir = root
  end

  def fixture_path
    T.bind(self, Minitest::Runnable)
    File.join(TEMP_FIXTURE_DIR, "#{name}-#{Time.now.strftime("%Y_%m_%d_%H_%M_%S")}")
  end
end
