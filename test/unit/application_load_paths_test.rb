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
  end
end
