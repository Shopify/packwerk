# typed: true
# frozen_string_literal: true

require "loading_test_helper"

module Packwerk
  class AutoloadTest < Minitest::Test
    include ActiveSupport::Testing::Isolation
    GEM_LIB = File.expand_path("../../../lib", __dir__)

    test "does not autoload early" do
      require "packwerk"

      assert_equal(
        ["#{GEM_LIB}/packwerk.rb", "#{GEM_LIB}/packwerk/version.rb"].sort,
        loaded_packwerk_files.sort,
      )
    end

    test "running sig blocks does not load extra files" do
      require "packwerk"
      before_sig_files = loaded_packwerk_files

      T::Utils.run_all_sig_blocks

      assert_equal(before_sig_files, loaded_packwerk_files)
    end

    private

    def loaded_packwerk_files
      $LOADED_FEATURES.select { |path| path.starts_with?(GEM_LIB) }
    end
  end
end
