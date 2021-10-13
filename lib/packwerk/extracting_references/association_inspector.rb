# typed: strict
# frozen_string_literal: true

module Packwerk
  # Extracts the implicit constant reference from an active record association
  class AssociationInspector
    extend T::Sig
    include ConstantNameInspector

    CustomAssociations = T.type_alias { T.any(T::Array[Symbol], T::Set[Symbol]) }

    RAILS_ASSOCIATIONS = T.let(
      %i(
        belongs_to
        has_many
        has_one
        has_and_belongs_to_many
      ).to_set,
      CustomAssociations
    )

    sig { params(inflector: Inflector, custom_associations: CustomAssociations).void }
    def initialize(inflector:, custom_associations: Set.new)
      @inflector = inflector
      @associations = T.let(RAILS_ASSOCIATIONS + custom_associations, CustomAssociations)
    end

    sig do
      override
        .params(node: AST::Node, ancestors: T::Array[AST::Node])
        .returns(T.nilable(String))
    end
    def constant_name_from_node(node, ancestors:)
      return unless Node.method_call?(node)
      return unless association?(node)

      arguments = Node.method_arguments(node)
      return unless (association_name = association_name(arguments))

      if (class_name_node = custom_class_name(arguments))
        return unless Node.string?(class_name_node)
        Node.literal_value(class_name_node)
      else
        @inflector.classify(association_name.to_s)
      end
    end

    private

    sig { params(node: AST::Node).returns(T::Boolean) }
    def association?(node)
      method_name = Node.method_name(node)
      @associations.include?(method_name)
    end

    sig { params(arguments: T::Array[AST::Node]).returns(T.nilable(AST::Node)) }
    def custom_class_name(arguments)
      association_options = arguments.detect { |n| Node.hash?(n) }
      return unless association_options

      Node.value_from_hash(association_options, :class_name)
    end

    sig { params(arguments: T::Array[AST::Node]).returns(T.any(T.nilable(Symbol), T.nilable(String))) }
    def association_name(arguments)
      return unless Node.symbol?(arguments[0])

      Node.literal_value(arguments[0])
    end
  end
end
