# typed: true
# frozen_string_literal: true

require "support/rails_test_helper"
require "zeitwerk"

module RailsApplicationFixtureHelper
  include Packwerk::ApplicationFixtureHelper

  class Autoloaders
    include Enumerable

    def initialize
      @main = Zeitwerk::Loader.new
      @once = Zeitwerk::Loader.new
    end

    attr_reader :main, :once

    def each(&block)
      yield(main)
      yield(once)
    end

    def zeitwerk_enabled?
      true
    end
  end

  def use_template(template)
    super(template)

    Rails.stubs(:autoloaders).returns(Autoloaders.new)

    case template
    when :minimal
      set_load_paths_for_minimal_template
    when :skeleton
      set_load_paths_for_skeleton_template
    when :ambiguous
      set_load_paths_for_ambiguous_template
    when :blank, :extended
    else
      raise "Unknown fixture template #{template}"
    end

    root = Pathname.new(app_dir)
    Rails.application.config.stubs(:root).returns(root)
  end

  private

  def set_load_paths_for_minimal_template
    Rails.autoloaders.main.push_dir(*to_app_paths("/components/sales/app/models"))
  end

  def set_load_paths_for_skeleton_template
    Rails.autoloaders.main.push_dir(*to_app_paths("/components/sales/app/models"))
    Rails.autoloaders.main.push_dir(*to_app_paths("/components/sales/app/public"))
    Rails.autoloaders.main.push_dir(*to_app_paths("components/platform/app/models"))

    Rails.autoloaders.once.push_dir(*to_app_paths("components/timeline/app/models"))
    Rails.autoloaders.once.push_dir(*to_app_paths("components/timeline/app/models/concerns"))
    Rails.autoloaders.once.push_dir(*to_app_paths("vendor/cache/gems/example/models"))
  end

  def set_load_paths_for_ambiguous_template
    Rails.autoloaders.main.push_dir(*to_app_paths("/components/sales/app/models"))
    Rails.autoloaders.main.push_dir(*to_app_paths("/components/sales/app/services"))
  end
end
