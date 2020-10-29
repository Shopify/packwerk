# typed: true
# frozen_string_literal: true

require "packwerk/constant_name_inspector"
require "packwerk/node"

module Packwerk
  # Extracts the implicit constant reference from an active record association
  class AssociationInspector
    include ConstantNameInspector

    RAILS_ASSOCIATIONS = %i(
      belongs_to
      has_many
      has_one
      has_and_belongs_to_many
    ).to_set

    def initialize(inflector: Inflector.new, custom_associations: Set.new)
      @inflector = inflector
      @associations = RAILS_ASSOCIATIONS + custom_associations
    end

    def constant_name_from_node(node, ancestors:)
      return unless node.method_call?
      return unless association?(node)

      arguments = node.method_arguments
      return unless (association_name = association_name(arguments))

      if (class_name_node = custom_class_name(arguments))
        return unless class_name_node.string?
        class_name_node.literal_value
      else
        @inflector.classify(association_name.to_s)
      end
    end

    private

    def association?(node)
      @associations.include?(node.method_name)
    end

    def custom_class_name(arguments)
      return unless (association_options = arguments.detect(&:hash?))

      association_options.value_from_hash(:class_name)
    end

    def association_name(arguments)
      return unless arguments[0].symbol?

      arguments[0].literal_value
    end
  end
end
