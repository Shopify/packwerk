# typed: strict
# frozen_string_literal: true

require "singleton"

module Packwerk
  module Parsers
    class Factory
      extend T::Sig
      include Singleton

      sig { params(path: String).returns(T::Array[Packwerk::FileParser]) }
      def for_path(path)
        Packwerk::FileParser.all.select { |parser| parser.match?(path: path) }
      end
    end
  end
end
