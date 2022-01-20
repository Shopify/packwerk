# typed: strict
# frozen_string_literal: true

module Packwerk
  class Result < T::Struct
    const :message, String
    const :status, T::Boolean
  end
end
