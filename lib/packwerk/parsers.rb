# typed: strict
# frozen_string_literal: true

module Packwerk
  module Parsers
    autoload :Erb, "packwerk/parsers/erb"
    autoload :Factory, "packwerk/parsers/factory"
    autoload :Ruby, "packwerk/parsers/ruby"

    # Require parsers so that they are registered with FileParser
    Dir[File.join(__dir__, "parsers", "*.rb")].each { |file| require file }

    class ParseResult < Offense; end

    class ParseError < StandardError
      extend T::Sig

      sig { returns(ParseResult) }
      attr_reader(:result)

      sig { params(result: ParseResult).void }
      def initialize(result)
        super(result.message)
        @result = result
      end
    end
  end
end
