# typed: strict
# frozen_string_literal: true

require "test_helper"
require "rails_test_helper"

module Packwerk
  class LoaderTest < Minitest::Test
    test ".root_dirs calls root_dirs when zeitwerk version is < 2.6.1" do
      with_stubbed_const(Zeitwerk, "VERSION", "2.6.0") do
        mock_loader = mock("loader")
        mock_loader.expects(:root_dirs).returns("roots")

        assert_equal(Packwerk::Loader.new(mock_loader).dirs(namespaces: true), "roots")
      end
    end

    test ".root_dirs calls __root when zeitwerk version is  2.6.1" do
      with_stubbed_const(Zeitwerk, "VERSION", "2.6.1") do
        mock_loader = mock("loader")
        mock_loader.expects(:dirs).returns("roots")

        assert_equal(Packwerk::Loader.new(mock_loader).dirs(namespaces: true), "roots")
      end
    end
  end
end
