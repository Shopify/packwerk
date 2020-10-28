# typed: strict
# frozen_string_literal: true

require "packwerk/constant_name_inspector"
require "packwerk/fixture_reference_inspector/fixture_retriever"
require "packwerk/node"

module Packwerk
  # Exracts the constant reference from a fixture call
  class FixtureReferenceInspector
    extend T::Sig
    include ConstantNameInspector

    sig { params(root_path: String, fixture_paths: T::Array[String]).void }
    def initialize(root_path:, fixture_paths:)
      @root_path = T.let(root_path, String)
      @fixture_paths = T.let(fixture_paths, T::Array[String])
    end

    sig { override.params(node: ::AST::Node, ancestors: T::Array[::AST::Node]).returns(T.nilable(String)) }
    def constant_name_from_node(node, ancestors:)
      return unless applies?(node)
      return unless (fixture = retrieve_fixture(node))

      constant = fixture.model_class
      if constant.start_with?("::")
        constant
      else
        "::#{constant}"
      end
    end

    private

    sig { returns(String) }
    attr_reader :root_path

    sig { returns(T::Array[String]) }
    attr_reader :fixture_paths

    sig { params(node: ::AST::Node).returns(T::Boolean) }
    def applies?(node)
      return false unless Node.method_call?(node)
      return false unless potential_fixture_call?(node)

      true
    end

    # s(:send, nil, :shop,
    #   s(:sym, :snowdevil))
    sig { params(node: ::AST::Node).returns(T::Boolean) }
    def potential_fixture_call?(node)
      arguments = Node.method_arguments(node)
      arguments.length == 1 && Node.symbol?(arguments[0])
    end

    sig { params(node: ::AST::Node).returns(T.nilable(Fixture)) }
    def retrieve_fixture(node)
      method_name = Node.method_name(node).to_s
      fixture_retrievers
        .first { |retriever| retriever.find_by!(method_name: method_name) }
        &.find_by!(method_name: method_name)
    end

    sig { returns(T::Array[FixtureRetriever]) }
    def fixture_retrievers
      @fixture_retrievers = T.let(@fixture_retrievers, T.nilable(T::Array[FixtureRetriever]))

      @fixture_retrievers ||= expanded_fixture_paths.map { |path| FixtureRetriever.new(path) }
    end

    sig { returns(T::Array[String]) }
    def expanded_fixture_paths
      @expanded_fixture_paths = T.let(@expanded_fixture_paths, T.nilable(T::Array[String]))

      @expanded_fixture_paths ||= fixture_paths.map { |path| File.join(root_path, path) }
    end
  end
end
