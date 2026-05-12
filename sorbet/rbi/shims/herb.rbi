# typed: strong

module Herb
  sig { params(source: String).returns(String) }
  def self.extract_ruby(source); end
end
