# typed: true
# frozen_string_literal: true

module Packwerk
  class Node
    Location = Struct.new(:line, :column)
  end

  private_constant :Node
end
