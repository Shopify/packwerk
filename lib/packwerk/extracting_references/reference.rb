# typed: true
# frozen_string_literal: true

module Packwerk
  Reference = Struct.new(:source_package, :relative_path, :constant)
end
