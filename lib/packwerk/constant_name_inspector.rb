# typed: strict
# frozen_string_literal: true

require "ast"

module Packwerk
  # An interface describing an object that can extract a constant name from an AST node.
  # @interface
  module ConstantNameInspector
    # @abstract
    #: (::AST::Node node, ancestors: Array[::AST::Node], relative_file: String) -> String?
    def constant_name_from_node(node, ancestors:, relative_file:) = raise NotImplementedError, "Abstract method called"
  end

  private_constant :ConstantNameInspector
end
