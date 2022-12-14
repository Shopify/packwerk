# typed: strict

class Parser::Base < ::Racc::Parser
  # Parses a source buffer and returns the AST, or `nil` in case of a non fatal error.
  #
  # @api public
  # @param source_buffer [Parser::Source::Buffer] The source buffer to parse.
  # @return [Parser::AST::Node, nil]
  #
  # source://parser-3.1.2.1/lib/parser/base.rb:186
  sig { params(source_buffer: Parser::Source::Buffer).returns(T.nilable(Parser::AST::Node)) }
  def parse(source_buffer); end
end
