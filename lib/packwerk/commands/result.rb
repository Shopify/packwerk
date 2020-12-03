# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module Packwerk
  module Commands
    class Result < T::Struct
      prop :message, String
      prop :status, T::Boolean
    end
  end
end
