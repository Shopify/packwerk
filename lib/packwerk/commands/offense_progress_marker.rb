# frozen_string_literal: true
# typed: strict
require "sorbet-runtime"
require "packwerk/formatters/progress_formatter"

module Packwerk
  module OffenseProgressMarker
    extend T::Sig

    sig do
      params(
        offenses: T::Array[T.nilable(::Packwerk::Offense)],
        progress_formatter: ::Packwerk::Formatters::ProgressFormatter
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
