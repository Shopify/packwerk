# typed: true
# frozen_string_literal: true

require "benchmark"
require "sorbet-runtime"

require "packwerk/inflector"
require "packwerk/output_styles"

module Packwerk
  module Formatters
    class OffensesFormatter
      extend T::Sig

      def initialize(out, style: OutputStyles::Plain)
        @out = out
        @style = style
      end

      sig { params(offenses: T::Array[T.nilable(Offense)]).void }
      def show_offenses(offenses)
        @out.puts # put a new line after the progress dots
        if offenses.empty?
          @out.puts("No offenses detected 🎉")
        else
          offenses.each do |offense|
            @out.puts(offense.to_s(@style)) if offense
          end

          offenses_string = Inflector.default.pluralize("offense", offenses.length)
          @out.puts("#{offenses.length} #{offenses_string} detected")
        end
      end
    end
  end
end
