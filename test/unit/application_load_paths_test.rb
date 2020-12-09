# typed: false
# frozen_string_literal: true

require "test_helper"
require "rails_test_helper"

module Packwerk
  class ApplicationLoadPathsTest < Minitest::Test
    test ".relative_path_strings makes paths relative" do
      rails_root = Pathname.new("/application/")
      relative_path = "app/models"
      absolute_path = rails_root.join(relative_path)
      relative_path_strings = ApplicationLoadPaths.relative_path_strings(
        [absolute_path],
        rails_root: rails_root
      )

      assert_equal [relative_path], relative_path_strings
    end

    test ".filter_relevant_paths excludes paths outside of the application root" do
      valid_paths = ["/application/app/models"]
      paths = valid_paths + ["/users/tobi/.gems/something/app/models", "/application/../something/"]
      filtered_paths = ApplicationLoadPaths.filter_relevant_paths(
        paths,
        bundle_path: Pathname.new("/application/vendor/"),
        rails_root: Pathname.new("/application/")
      )

      assert_equal valid_paths, filtered_paths.map(&:to_s)
    end

    test ".filter_relevant_paths excludes paths from vendored gems" do
      valid_paths = ["/application/app/models"]
      paths = valid_paths + ["/application/vendor/something/app/models"]
      filtered_paths = ApplicationLoadPaths.filter_relevant_paths(
        paths,
        bundle_path: Pathname.new("/application/vendor/"),
        rails_root: Pathname.new("/application/")
      )

      assert_equal valid_paths, filtered_paths.map(&:to_s)
    end

    test ".extract_relevant_paths calls out to filter the paths" do
      ApplicationLoadPaths.expects(:filter_relevant_paths).once.returns([Pathname.new("/fake_path")])
      ApplicationLoadPaths.extract_relevant_paths
    end

    test ".extract_relevant_paths returns unique load paths" do
      path = Pathname.new("/application/app/models")
      ApplicationLoadPaths.expects(:filter_relevant_paths).once.returns([path, path])

      assert_equal 1, ApplicationLoadPaths.extract_relevant_paths.count
    end

    test ".extract_application_autoload_paths returns unique autoload paths" do
      path = Pathname.new("/application/app/models")
      Rails.application.config.expects(:autoload_paths).once.returns([path])
      Rails.application.config.expects(:eager_load_paths).once.returns([path])
      Rails.application.config.expects(:autoload_once_paths).once.returns([path])

      assert_equal 1, ApplicationLoadPaths.extract_application_autoload_paths.count
    end

    test ".extract_application_autoload_paths returns autoload paths as strings" do
      path = Pathname.new("/application/app/models")
      Rails.application.config.expects(:autoload_paths).once.returns([path])

      assert_instance_of String, ApplicationLoadPaths.extract_application_autoload_paths.first
    end
  end
end
