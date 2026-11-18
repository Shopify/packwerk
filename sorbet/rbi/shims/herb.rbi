# typed: strict

# Tapioca can't generate an RBI for herb yet: its RBS rewriter fails on the `(...)`
# parameters Herb uses. This mirrors the signature in herb's own `sig/herb.rbs`.
module Herb
  class << self
    #: (
    #|   String source,
    #|   ?semicolons: bool,
    #|   ?comments: bool,
    #|   ?preserve_positions: bool,
    #|   ?custom_tags: bool,
    #|   ?erb_openers: Array[String]
    #| ) -> String
    def extract_ruby(source, semicolons: true, comments: false, preserve_positions: true, custom_tags: false, erb_openers: []); end
  end
end
