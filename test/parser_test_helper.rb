# typed: false
# frozen_string_literal: true

module ParserTestHelper
  class << self
    def parse(source)
      Packwerk::Parsers::Ripper.new.call(io: StringIO.new(source))
      # Packwerk::Parsers::Ruby.new.call(io: StringIO.new(source))
    end
  end
end
