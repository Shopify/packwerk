# typed: strict
# frozen_string_literal: true

module Packwerk
  class Result < T::Struct
    prop :message, String
    prop :status, T::Boolean
  end
end
