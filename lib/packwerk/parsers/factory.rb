# typed: true
# frozen_string_literal: true

require "singleton"

module Packwerk
  module Parsers
    class Factory
      extend T::Sig
      include Singleton

      sig { params(path: String).returns(T.nilable(Packwerk::Parser)) }
      def for_path(path)
        Packwerk::Parser.all.find { |parser| parser.match?(path: path) }
      end
    end
  end
end
