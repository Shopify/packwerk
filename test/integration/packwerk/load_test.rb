# typed: true
# frozen_string_literal: true

require "test_helper"
require "active_support/testing/isolation"

module Packwerk
  class LoadTest < Minitest::Test
    include ActiveSupport::Testing::Isolation
    GEM_LIB = File.expand_path("../../../lib", __dir__)

    setup { unload_packwerk }

    test "does not autoload early" do
      require "packwerk"

      assert_equal(
        ["#{GEM_LIB}/packwerk.rb", "#{GEM_LIB}/packwerk/version.rb"].sort,
        loaded_packwerk_files.sort,
      )
    end

    private

    def loaded_packwerk_files
      $LOADED_FEATURES.select { |path| path.starts_with?(GEM_LIB) }
    end

    def unload_packwerk
      $LOADED_FEATURES.delete_if { |path| path.starts_with?(GEM_LIB) }
      Object.send(:remove_const, :Packwerk)
    end
  end
end
