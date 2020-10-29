# typed: true
# frozen_string_literal: true

module Packwerk
  class Ancestors
    attr_reader :ancestors

    def initialize(ancestors)
      @ancestors = ancestors
    end

    def parent_module_name
      ancestor_names.empty? ? "Object" : names.reverse.join("::")
    end

    def enclosing_namespace_path(starting_node)
      ancestors.select { |n| n.module? || n.class? }
        .each_with_object([]) do |node, namespace|
        # when evaluating `class Child < Parent`, the const node for `Parent` is a child of the class
        # node, so it'll be an ancestor, but `Parent` is not evaluated in the namespace of `Child`, so
        # we need to skip it here
        next if node.class? && node.parent_class == starting_node

        namespace.prepend(class_or_module_name(node))
      end
    end

    private

    def ancestor_names
      ancestors
        .select { |n| n.class? || n.module? || n.constant_assignment? || n.block? }
        .map(&:name_part_from_definition)
        .compact
    end
  end
end
