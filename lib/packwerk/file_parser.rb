# typed: strict
# frozen_string_literal: true

module Packwerk
  module FileParser
    extend T::Helpers
    extend T::Sig

    requires_ancestor { Kernel }

    interface!

    @parsers = T.let([], T::Array[T::Class[T.anything]])

    class << self
      extend T::Sig

      sig { params(base: T::Class[T.anything]).void }
      def included(base)
        @parsers << base
      end

      sig { returns(T::Array[FileParser]) }
      def all
        T.unsafe(@parsers).map(&:new)
      end

      sig { params(base: T::Class[T.anything]).void }
      def remove(base)
        @parsers.delete(base)
      end
    end

    sig { abstract.params(io: T.any(IO, StringIO), file_path: String).returns(T.untyped) }
    def call(io:, file_path:)
    end

    sig { abstract.params(path: String).returns(T::Boolean) }
    def match?(path:)
    end
  end
end
