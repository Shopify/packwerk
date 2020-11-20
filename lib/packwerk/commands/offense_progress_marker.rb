# frozen_string_literal: true
# typed: strict

module Packwerk
  module Commands
    module OffenseProgressMarker
      extend T::Sig

      sig do
        params(
          offenses: T::Array[T.nilable(Offense)],
          progress_formatter: Formatters::ProgressFormatter
        ).void
      end
      def mark_progress(offenses:, progress_formatter:)
        if offenses.empty?
          progress_formatter.mark_as_inspected
        else
          progress_formatter.mark_as_failed
        end
      end
    end
  end
end
