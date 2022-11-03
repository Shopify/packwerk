# typed: true
# frozen_string_literal: true

module Packwerk
  class Loader < SimpleDelegator
    INTROSPECTION_SUPPORTED_VERSION = "2.6.1"

    class << self
      extend T::Sig

      sig { returns(T::Array[Loader]) }
      def autoloaders
        Rails.autoloaders.map do |loader|
          new(loader)
        end
      end
    end

    def dirs(namespaces:)
      if Zeitwerk::VERSION < INTROSPECTION_SUPPORTED_VERSION
        __getobj__.root_dirs
      else
        super
      end
    end
  end
end
