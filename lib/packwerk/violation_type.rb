# typed: true
# frozen_string_literal: true

require "sorbet-runtime"

module Packwerk
  class ViolationType < T::Enum
    enums do
      Privacy = new
      Dependency = new
    end
  end
end
