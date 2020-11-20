# frozen_string_literal: true
# typed: strict

module Packwerk
  module Commands
    module OffensePrinter
      extend T::Sig

      sig do
        params(
          offenses: T::Array[Offense],
          out: StringIO,
          style: T.any(T.class_of(OutputStyles::Plain), T.class_of(OutputStyles::Coloured))
        ).void
      end
      def show_offenses(offenses, out, style)
        if offenses.empty?
          out.puts("No offenses detected 🎉")
        else
          offenses.each do |offense|
            out.puts(offense.to_s(style))
          end

          offenses_string = Inflector.default.pluralize("offense", offenses.length)
          out.puts("#{offenses.length} #{offenses_string} detected")
        end
      end
    end
  end
end
