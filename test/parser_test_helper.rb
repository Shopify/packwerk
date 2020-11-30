# typed: false
# frozen_string_literal: true

require "packwerk/parsers/ruby"

module ParserTestHelper
  class << self
    def parse(source)
      Packwerk::Parsers::Ruby.new.call(io: StringIO.new(source))
    end
  end
end
