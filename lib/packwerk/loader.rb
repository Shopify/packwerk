# typed: true
# frozen_string_literal: true

module Packwerk
  class Loader < SimpleDelegator
    ROOT_DIRS_DEPRECATION_VERSION = "2.6.4"

    def self.autoloaders
      Rails.autoloaders.map do |loader|
        new(loader)
      end
    end

    def root_dirs
      return super if Zeitwerk::VERSION < ROOT_DIRS_DEPRECATION_VERSION

      __roots
    end
  end
end
