# typed: true
# frozen_string_literal: true

require "ripper"
require "ast"
require "pp"

module Packwerk
  module Parsers
    class Ripper
      extend T::Sig

      def call(io:, file_path: "<unknown>")
        parser = RipperToast.new(io, file_path)
        ast = parser.parse
        raise if parser.error?
        ast
      rescue EncodingError => e
        result = ParseResult.new(file: file_path, message: e.message)
        raise Parsers::ParseError, result
      # rescue Parser::SyntaxError => e
      #   result = ParseResult.new(file: file_path, message: "Syntax error: #{e}")
      #   raise Parsers::ParseError, result
      end

      class AST::Node
        def location
          nil
        end
      end

      class LocationNode < AST::Node
        attr_reader :location

        def initialize(type, line, column, *children)
          @location = OpenStruct.new(name: OpenStruct.new(line: line, column: column))
          super(type, children)
        end
      end

      class RipperToast < ::Ripper
        extend T::Sig

        private
        include AST::Sexp

        #
        # The ripper parser event handlers
        #
        def on_stmts_new; []; end
        def on_void_stmt; nil; end
        def on_stmts_add(stmts, stmt); stmts << stmt; end
        def on_program(ast); sequence(ast); end
        def on_var_field(ident); ident; end
        def on_assign(ident, value)
          if ident.is_a?(AST::Node) && ident.type == :const
            parent, name = ident.children[0..1]
            location = ident.location.name
            LocationNode.new(:casgn, location.line, location.column, parent, name, value)
          else
            s(:lvasgn, ident, value)
          end
        end
        def on_const_ref(const); const; end
        def on_bodystmt(stmts, rescued, ensured, elsed)
          raise if rescued
          raise if ensured
          raise if elsed
          stmts
        end

        sig { params(name: AST::Node, bodystmt: T::Array[T.nilable(AST::Node)]).returns(AST::Node) }
        def on_module(name, bodystmt)
          s(:module, name, sequence(bodystmt))
        end

        sig {
          params(const: AST::Node, superclass: T.nilable(AST::Node), bodystmt: T::Array[T.nilable(AST::Node)])
            .returns(AST::Node)
        }
        def on_class(const, superclass, bodystmt)
          s(:class, const, superclass, sequence(bodystmt))
        end
        def on_var_ref(const); const; end
        def on_vcall(ident); s(:send, nil, ident); end
        def on_fcall(message); s(:send, nil, message); end
        def on_string_content(*); nil; end
        def on_string_add(*); nil; end
        def on_string_literal(*); nil; end
        def on_const_path_ref(left, const); set_const_parent(const, left); end
        def on_const_path_field(left, const); set_const_parent(const, left); end
        sig { params(const: AST::Node).returns(AST::Node) }
        def on_top_const_ref(const); set_const_parent(const, s(:cbase)); end
        def on_binary(left, operator, right); s(:send, left, operator, right); end
        def on_call(receiver, operator, message)
          p __method__, receiver, operator, message
          s(:send, receiver, message)
        end
        def on_command(message, args); s(:send, nil, message, *args); end
        def on_params(req, opts, rest, post, keys, keyrest, block)
          p __method__, req, opts, rest, post, keys, keyrest, block
          s(:args, *req.map { |p| s(:arg, p) } )
        end
        def on_block_var(params, locals)
          raise if locals
          params
        end
        def on_do_block(block_var, bodystmt)
          [block_var, *bodystmt]
        end
        def on_brace_block(block_var, bodystmt)
          [block_var, *bodystmt]
        end
        def on_args_new; []; end
        def on_method_add_arg(method, args); method.concat(args); end
        def on_method_add_block(method, block)
          args = block[0] || s(:args)
          s(:block, method, args, sequence(block[1..]))
        end
        def on_args_add(args, arg); args << arg; end
        def on_args_add_block(args, block)
          raise if block
          args
        end
        def on_arg_paren(args); args; end
        def on_begin(stmts); s(:kwbegin, sequence(stmts)); end
        def on_symbol(contents); contents; end
        def on_symbol_literal(contents); s(:sym, contents.to_sym); end
        def on_assoc_new(key, value)
          s(:pair, key, value)
        end
        def on_assoclist_from_args(assocs)
          s(:hash, *assocs)
        end
        def on_hash(assoclist); assoclist; end

        #
        # The ripper scanner event handlers
        #
        def on_int(value); s(:int, Integer(value)); end
        def on_sp(_); nil; end
        def on_op(_); nil; end
        def on_ident(name); name.to_sym; end
        def on_const(name); LocationNode.new(:const, lineno, column, nil, name.to_sym); end
        def on_semicolon(_); nil; end
        def on_kw(kw)
          if kw == "self"
            s(:self)
          end
        end
        def on_tstring_beg(*); nil; end
        def on_tstring_content(*); nil; end
        def on_tstring_end(*); nil; end
        def on_comment(*); nil; end
        def on_period(*); nil; end
        def on_comma(*); nil; end
        def on_lparen(*); nil; end
        def on_rparen(*); nil; end
        def on_lbrace(*); nil; end
        def on_rbrace(*); nil; end
        def on_symbeg(*); nil; end
        def on_label(name); s(:sym, name[..-2].to_sym); end

        #
        # Helper methods
        #
        sig { params(array: Array).returns(T.nilable(AST::Node)) }
        def sequence(array)
          compacted = array.compact
          return nil if compacted == []
          return compacted.first if compacted.length == 1
          s(:begin, *compacted)
        end
        sig { params(const: AST::Node, parent: AST::Node).returns(AST::Node) }
        def set_const_parent(const, parent)
          raise unless const.type == :const

          old_parent, name = const.children[0..1]
          raise if old_parent

          location = const.location.name
          LocationNode.new(:const, location.line, location.column, parent, name)
        end

        #
        # Raise on all unimplemented event methods.
        # We have to overwrite the aliases from the parent class
        #
        all_events = PARSER_EVENT_TABLE.keys + SCANNER_EVENTS
        unhandled_events = all_events.reject { |event| private_instance_methods(false).include?(:"on_#{event}") }
        unhandled_events.each do |event|
          name = "on_#{event}"
          define_method(name.to_sym) { |*params| raise NotImplementedError.new("#{name} (params #{params.inspect})") }
        end
      end
    end
  end
end
