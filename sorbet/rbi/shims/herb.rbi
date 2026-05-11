# typed: strict

module Herb
  class << self
    #: (String source, ?semicolons: bool, ?comments: bool, ?preserve_positions: bool) -> String
    def extract_ruby(source, semicolons: true, comments: false, preserve_positions: true); end
  end
end
