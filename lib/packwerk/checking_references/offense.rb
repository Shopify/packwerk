# typed: true
# frozen_string_literal: true

require "parser/source/map"

module Packwerk
  class Offense
    extend T::Sig
    extend T::Helpers

    attr_reader :location, :file, :message

    sig do
      params(file: String, message: String, location: T.nilable(Node::Location))
        .void
    end
    def initialize(file:, message:, location: nil)
      @location = location
      @file = file
      @message = message
    end

    sig { params(style: OutputStyle).returns(String) }
    def to_s(style = OutputStyles::Plain.new)
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
