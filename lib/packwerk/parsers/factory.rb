# typed: strict
# frozen_string_literal: true

require "singleton"

module Packwerk
  module Parsers
    class Factory
      extend T::Sig
      include Singleton

      RUBY_REGEX = %r{
        # Although not important for regex, these are ordered from most likely to match to least likely.
        \.(rb|rake|builder|gemspec|ru)\Z
        |
        (Gemfile|Rakefile)\Z
      }x
      private_constant :RUBY_REGEX

      ERB_REGEX = /\.erb\Z/
      private_constant :ERB_REGEX

      #: -> void
      def initialize
        @ruby_parser = nil #: ParserInterface?
        @erb_parser = nil #: ParserInterface?
        @erb_parser_class = nil #: Class[top]?
      end

      #: (String path) -> ParserInterface?
      def for_path(path)
        case path
        when RUBY_REGEX
          @ruby_parser ||= Ruby.new
        when ERB_REGEX
          @erb_parser ||= T.unsafe(erb_parser_class).new
        end
      end

      #: -> Class[top]
      def erb_parser_class
        @erb_parser_class ||= Erb
      end

      #: (Class[top]? klass) -> void
      def erb_parser_class=(klass)
        @erb_parser_class = klass
        @erb_parser = nil
      end
    end
  end
end
