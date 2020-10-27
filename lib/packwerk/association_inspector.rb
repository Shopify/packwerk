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
      return unless Node.method_call?(node)
      return unless association?(node)

      arguments = Node.method_arguments(node)
      association_name = Node.literal_value(arguments[0]) if Node.symbol?(arguments[0])
      return nil unless association_name

      association_options = arguments.detect { |n| Node.hash?(n) }
      class_name_node = Node.value_from_hash(association_options, :class_name) if association_options

      if class_name_node
        Node.literal_value(class_name_node) if Node.string?(class_name_node)
      else
        @inflector.classify(association_name.to_s)
      end
    end

    private

    def association?(node)
      method_name = Node.method_name(node)
      @associations.include?(method_name)
    end
  end
end
