# typed: true
# frozen_string_literal: true

require "ast"

module Packwerk
  # An interface describing some object that can extract a constant name from an AST node
  module ConstantNameInspector
    extend T::Sig
    extend T::Helpers

    interface!

    sig do
      params(node: ::AST::Node, ancestors: T::Array[::AST::Node])
        .returns(T.nilable(String))
        .abstract
    end
    def constant_name_from_node(node, ancestors:); end
  end
end
