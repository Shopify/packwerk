# typed: true
# frozen_string_literal: true

require "parser/source/map"
require "sorbet-runtime"

require "packwerk/output_style"
require "packwerk/output_styles/plain"

module Packwerk
  class Offense
    extend T::Sig
    extend T::Helpers

    attr_reader :location, :file, :message, :reference, :violation_type

    sig do
      params(file: String, message: String, reference: Packwerk::Reference, violation_type: Packwerk::ViolationType, location: T.nilable(Node::Location))
        .void
    end
    def initialize(file:, message:, reference:, violation_type:, location: nil)
      @location = location
      @file = file
      @message = message
      @reference = reference
      @violation_type = violation_type
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
