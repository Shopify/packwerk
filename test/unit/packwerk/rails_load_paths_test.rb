# typed: strict
# frozen_string_literal: true

require "test_helper"
require "support/rails_test_helper"

module Packwerk
  class RailsLoadPathsTest < Minitest::Test
    test ".for makes paths relative" do
      RailsLoadPaths.expects(:require_application).with("/application/", "test").once.returns(true)
      rails_root = Pathname.new("/application/")
      Rails.expects(:root).twice.returns(rails_root)
      relative_path = "app/models"
      absolute_path = rails_root.join(relative_path)
      RailsLoadPaths.expects(:extract_application_autoload_paths).once.returns(absolute_path.to_s => Object)
      relative_path_strings = RailsLoadPaths.for(rails_root.to_s, environment: "test")
      assert_equal({ relative_path => Object }, relative_path_strings)
    end

    test ".for excludes paths from vendored gems" do
      RailsLoadPaths.expects(:require_application).with("/application/", "test").once.returns(true)
      rails_root = Pathname.new("/application/")
      Rails.expects(:root).twice.returns(rails_root)
      Bundler.expects(:bundle_path).once.returns(Pathname.new("/application/vendor/"))

      valid_paths = ["/application/app/models"]
      paths = valid_paths + ["/application/vendor/something/app/models"]
      paths = paths.each_with_object({}) { |p, h| h[p.to_s] = Object }
      RailsLoadPaths.expects(:extract_application_autoload_paths).once.returns(paths)

      filtered_path_strings = RailsLoadPaths.for(rails_root.to_s, environment: "test")

      assert_equal({ "app/models" => Object }, filtered_path_strings.transform_keys(&:to_s))
    end

    test ".for calls out to filter the paths" do
      RailsLoadPaths.expects(:filter_relevant_paths).once.returns(Pathname.new("/fake_path").to_s => Object)
      RailsLoadPaths.expects(:require_application).with("/application", "test").once.returns(true)

      RailsLoadPaths.for("/application", environment: "test")
    end
  end
end
