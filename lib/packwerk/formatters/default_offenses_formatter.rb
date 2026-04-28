# typed: strict
# frozen_string_literal: true

module Packwerk
  module Formatters
    class DefaultOffensesFormatter
      include OffensesFormatter

      IDENTIFIER = "default" #: String

      extend T::Sig

      # @override
      #: (Array[Offense?] offenses) -> String
      def show_offenses(offenses)
        return "No offenses detected" if offenses.empty?

        <<~EOS
          #{offenses_list(offenses)}
          #{offenses_summary(offenses)}
        EOS
      end

      # @override
      #: (OffenseCollection offense_collection, Set[String] file_set) -> String
      def show_stale_violations(offense_collection, file_set)
        if offense_collection.stale_violations?(file_set)
          "There were stale violations found, please run `packwerk update-todo`"
        else
          "No stale violations detected"
        end
      end

      # @override
      #: -> String
      def identifier
        IDENTIFIER
      end

      # @override
      #: (Array[ReferenceOffense] strict_mode_violations) -> String
      def show_strict_mode_violations(strict_mode_violations)
        if strict_mode_violations.any?
          strict_mode_violations.compact.map { |offense| format_strict_mode_violation(offense) }.join("\n")
        else
          ""
        end
      end

      private

      #: -> OutputStyle
      def style
        @style ||= Packwerk::OutputStyles::Coloured.new #: Packwerk::OutputStyles::Coloured?
      end

      #: (ReferenceOffense offense) -> String
      def format_strict_mode_violation(offense)
        reference_package = offense.reference.package
        defining_package = offense.reference.constant.package
        "#{reference_package} cannot have #{offense.violation_type} violations on #{defining_package} "\
          "because strict mode is enabled for #{offense.violation_type} violations in "\
          "the enforcing package's package.yml"
      end

      #: (Array[Offense?] offenses) -> String
      def offenses_list(offenses)
        offenses
          .compact
          .map { |offense| offense.to_s(style) }
          .join("\n")
      end

      #: (Array[Offense?] offenses) -> String
      def offenses_summary(offenses)
        offenses_string = "offense".pluralize(offenses.length)
        "#{offenses.length} #{offenses_string} detected"
      end
    end
  end
end
