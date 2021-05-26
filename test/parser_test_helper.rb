# typed: false
# frozen_string_literal: true

module ParserTestHelper
  class << self
    def parse(source)
      Packwerk::Parsers::Ruby.new.call(io: StringIO.new(source))
    end
  end
end
