# typed: strict
# frozen_string_literal: true

module Packwerk
  # Extracts the implicit constant reference from an active record association
  class AssociationInspector
    extend T::Sig
    include ConstantNameInspector

    CustomAssociations = T.type_alias { T.any(T::Array[Symbol], T::Set[Symbol]) }

    RAILS_ASSOCIATIONS = [
      :belongs_to,
      :has_many,
      :has_one,
      :has_and_belongs_to_many,
    ].to_set #: CustomAssociations

    #: (
    #|   inflector: singleton(ActiveSupport::Inflector),
    #|   ?custom_associations: CustomAssociations,
    #|   ?excluded_files: Set[String]
    #| ) -> void
    def initialize(inflector:, custom_associations: Set.new, excluded_files: Set.new)
      @inflector = inflector
      @associations = RAILS_ASSOCIATIONS + custom_associations #: CustomAssociations
      @excluded_files = excluded_files #: Set[String]
    end

    # @override
    #: (AST::Node node, ancestors: Array[AST::Node], relative_file: String) -> String?
    def constant_name_from_node(node, ancestors:, relative_file:)
      return unless NodeHelpers.method_call?(node)
      return if excluded?(relative_file)
      return unless association?(node)

      arguments = NodeHelpers.method_arguments(node)
      return unless (association_name = association_name(arguments))

      if (class_name_node = custom_class_name(arguments))
        return unless NodeHelpers.string?(class_name_node)

        NodeHelpers.literal_value(class_name_node)
      else
        @inflector.classify(association_name.to_s)
      end
    end

    private

    #: (String relative_file) -> bool
    def excluded?(relative_file)
      @excluded_files.include?(relative_file)
    end

    #: (AST::Node node) -> bool
    def association?(node)
      method_name = NodeHelpers.method_name(node)
      @associations.include?(method_name)
    end

    #: (Array[AST::Node] arguments) -> AST::Node?
    def custom_class_name(arguments)
      association_options = arguments.detect { |n| NodeHelpers.hash?(n) }
      return unless association_options

      NodeHelpers.value_from_hash(association_options, :class_name)
    end

    #: (Array[AST::Node] arguments) -> (Symbol | String)?
    def association_name(arguments)
      association_name_node = T.must(arguments[0])
      return unless NodeHelpers.symbol?(association_name_node)

      NodeHelpers.literal_value(association_name_node)
    end
  end

  private_constant :AssociationInspector
end
