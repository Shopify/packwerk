# typed: true
# frozen_string_literal: true


require "ripper"
require "ast"
require "pp"

module Packwerk
  module Parsers
    class Ripper
      extend T::Sig
      include AST::Sexp

      def call(io:, file_path: "<unknown>")
        transform(::Ripper.sexp(io.read, file_path))
      rescue EncodingError => e
        result = ParseResult.new(file: file_path, message: e.message)
        raise Parsers::ParseError, result
      rescue Parser::SyntaxError => e
        result = ParseResult.new(file: file_path, message: "Syntax error: #{e}")
        raise Parsers::ParseError, result
      end

      sig { params(sexp_node: Array).returns(T.nilable(::AST::Node)) }
      def transform(sexp_node)
        type = sexp_node.first

        case type
        when :program
          children = sexp_node[1]
          if children.length == 1
            transform(children.first)
          else
            s(:begin, *children.map { |c| transform(c) })
          end
        when :@int
          value = Integer(sexp_node[1])
          s(:int, value)
        when :assign
          lhs = sexp_node[1]
          rhs = sexp_node[2]
          if lhs.first == :var_field
            case lhs[1][0]
            when :@ident
              var_name = lhs[1][1]
              s(:lvasgn, var_name.to_sym, transform(rhs))
            when :@const
              const_name = lhs[1][1]
              s(:casgn, nil, const_name.to_sym, transform(rhs))
            end
          end
        when :module
          name_sexp = sexp_node[1]
          body_sexp = sexp_node[2]
          name_ast =
            if name_sexp[0] == :const_ref
              if name_sexp[1][0] == :@const
                s(:const, nil, name_sexp[1][1].to_sym)
              end
            end
          body_ast =
            if body_sexp[0] == :bodystmt
              if body_sexp[1][0] == [:void_stmt]
                nil
              end
            end
          s(:module, name_ast, body_ast)
        end
      end
    end
  end
end
