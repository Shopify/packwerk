# typed: strict
# frozen_string_literal: true

module Packwerk
  module Parser
    extend T::Helpers
    extend T::Sig

    interface!

    sig { abstract.params(io: File, file_path: String).returns(T.untyped) }
    def call(io:, file_path:)
    end

    module ClassMethods
      extend T::Sig
      extend T::Helpers

      abstract!

      sig { abstract.params(path: String).returns(T.boolean) }
      def match?(path:)
      end
    end

    mixes_in_class_methods(ClassMethods)
  end
end
