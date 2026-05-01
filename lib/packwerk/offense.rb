# typed: strict
# frozen_string_literal: true

require "parser"

module Packwerk
  class Offense
    #: Node::Location?
    attr_reader :location

    #: String
    attr_reader :file

    #: String
    attr_reader :message

    #: (file: String, message: String, ?location: Node::Location?) -> void
    def initialize(file:, message:, location: nil)
      @location = location
      @file = file
      @message = message
    end

    #: (?OutputStyle style) -> String
    def to_s(style = OutputStyles::Plain.new)
      location = self.location
      if location
        <<~EOS
          #{style.filename}#{file}#{style.reset}:#{location.line}:#{location.column}
          #{@message}
        EOS
      else
        <<~EOS
          #{style.filename}#{file}#{style.reset}
          #{@message}
        EOS
      end
    end
  end
end
