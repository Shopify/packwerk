# typed: true
# frozen_string_literal: true

require "ast"
require "sorbet-runtime"

module Packwerk
  # An interface describing some object that can extract a constant name from an AST node
  module ConstantNameInspector
    extend T::Sig
    extend T::Helpers

    interface!

    sig do
      params(node: ::RubyVM::AbstractSyntaxTree::Node, ancestors: T::Array[::RubyVM::AbstractSyntaxTree::Node])
        .returns(T.nilable(String))
        .abstract
    end
    def constant_name_from_node(node, ancestors:); end
  end
end
