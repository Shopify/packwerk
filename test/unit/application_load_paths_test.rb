# typed: strict
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
        { absolute_path => Object },
        rails_root: rails_root
      )

      assert_equal({ relative_path => Object }, relative_path_strings)
    end

    test ".filter_relevant_paths excludes paths outside of the application root" do
      valid_paths = ["/application/app/models"]
      paths = valid_paths + ["/users/tobi/.gems/something/app/models", "/application/../something/"]
      paths = paths.each_with_object({}) { |p, h| h[p.to_s] = Object }
      filtered_paths = ApplicationLoadPaths.filter_relevant_paths(
        paths,
        bundle_path: Pathname.new("/application/vendor/"),
        rails_root: Pathname.new("/application/")
      )

      assert_equal({ "/application/app/models" => Object }, filtered_paths.transform_keys(&:to_s))
    end

    test ".filter_relevant_paths excludes paths from vendored gems" do
      valid_paths = ["/application/app/models"]
      paths = valid_paths + ["/application/vendor/something/app/models"]
      paths = paths.each_with_object({}) { |p, h| h[p.to_s] = Object }
      filtered_paths = ApplicationLoadPaths.filter_relevant_paths(
        paths,
        bundle_path: Pathname.new("/application/vendor/"),
        rails_root: Pathname.new("/application/")
      )

      assert_equal({ "/application/app/models" => Object }, filtered_paths.transform_keys(&:to_s))
    end

    test ".extract_relevant_paths calls out to filter the paths" do
      ApplicationLoadPaths.expects(:filter_relevant_paths).once.returns(Pathname.new("/fake_path").to_s => Object)
      ApplicationLoadPaths.expects(:require_application).with("/application", "test").once.returns(true)

      ApplicationLoadPaths.extract_relevant_paths("/application", "test")
    end
  end
end
