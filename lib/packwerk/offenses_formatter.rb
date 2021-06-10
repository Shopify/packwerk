# typed: strict
# frozen_string_literal: true

module Packwerk
  module OffensesFormatter
    extend T::Sig
    extend T::Helpers

    interface!

    sig { abstract.params(offenses: T::Array[T.nilable(Offense)]).returns(String) }
    def show_offenses(offenses)
    end
  end
end
