# typed: strict
# frozen_string_literal: true

require "test_helper"
require "rails_test_helper"

module Packwerk
  class LoaderTest < Minitest::Test
    test ".root_dirs calls root_dirs when zeitwerk version is < 2.6.4" do
      with_stubbed_const(Zeitwerk, "VERSION", "2.6.3") do
        mock_loader = mock("loader")
        mock_loader.expects(:root_dirs).returns("roots")

        assert_equal(Packwerk::Loader.new(mock_loader).root_dirs, "roots")
      end
    end

    test ".root_dirs calls __root when zeitwerk version is  2.6.4" do
      with_stubbed_const(Zeitwerk, "VERSION", "2.6.4") do
        mock_loader = mock("loader")
        mock_loader.expects(:__roots).returns("roots")

        assert_equal(Packwerk::Loader.new(mock_loader).root_dirs, "roots")
      end
    end
  end
end
