# typed: ignore
# frozen_string_literal: true

require "packwerk/parsers/ruby"
require "packwerk/node/node_factory"

module ParserTestHelper
  class << self
    def parse(source)
      result = Packwerk::Parsers::Ruby.new.call(io: StringIO.new(source))
      NodeFactory.for(result)
    end
  end
end
