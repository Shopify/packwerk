# typed: true
# frozen_string_literal: true

require "parser/source/map"
require "sorbet-runtime"

require "packwerk/output_styles"

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

    sig do
      params(style: T.any(T.class_of(OutputStyles::Plain), T.class_of(OutputStyles::Coloured)))
        .returns(String)
    end
    def to_s(style = OutputStyles::Plain)
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
