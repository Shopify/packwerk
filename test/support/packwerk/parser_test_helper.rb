# typed: true
# frozen_string_literal: true

module Packwerk
  module ParserTestHelper
    class << self
      def parse(source)
        Parsers::Ruby.new.call(io: StringIO.new(source))
      end
    end
  end
end
