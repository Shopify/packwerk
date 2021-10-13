# typed: true
# frozen_string_literal: true

module Packwerk
  class ViolationType < T::Enum
    enums do
      Privacy = new
      Dependency = new
    end
  end
end
