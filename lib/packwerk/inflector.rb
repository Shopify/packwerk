# frozen_string_literal: true
# typed: strict

module Packwerk
  class Inflector
    extend T::Sig
    include ::ActiveSupport::Inflector # For #camelize, #classify, #pluralize, #singularize

    sig { params(inflections: ActiveSupport::Inflector::Inflections).void }
    def initialize(inflections)
      @inflections = inflections
    end

    sig { params(_: T.untyped).returns(ActiveSupport::Inflector::Inflections) }
    def inflections(_ = nil)
      @inflections
    end
  end
end
