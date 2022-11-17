# typed: true
# frozen_string_literal: true

require "singleton"

module Packwerk
  module Parsers
    class Factory
      extend T::Sig
      include Singleton

      DEFAULT_PARSERS = T.let([
        Ruby,
        Erb,
      ], T::Array[Packwerk::Parser])

      sig { returns(T::Array[Packwerk::Parser]) }
      attr_accessor :parsers

      sig { void }
      def initialize
        @parsers = T.let(DEFAULT_PARSERS, T::Array[Packwerk::Parser])
      end

      sig { params(path: String).returns(T.nilable(Packwerk::Parser)) }
      def for_path(path)
        parser_for_path = parsers.find { |parser| parser.match?(path) }

        parser_for_path&.new
      end
    end
  end
end
