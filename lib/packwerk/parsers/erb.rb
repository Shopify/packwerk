# typed: strict
# frozen_string_literal: true

require "herb"

module Packwerk
  module Parsers
    # Extracts the Ruby source embedded in an ERB template using Herb, the
    # Shopify ERB parser. Herb correctly handles ERB blocks that span tags
    # (e.g. `<%= form_for(:user) do |f| %>...<% end %>`) and preserves the
    # original line/column positions so reported violations point at the
    # actual ERB source location.
    class Erb
      #: (file_path: String) -> String?
      def extract_ruby_source(file_path:)
        source = File.read(file_path, encoding: Encoding::UTF_8)
        ruby = Herb.extract_ruby(source)
        ruby.empty? ? nil : ruby
      rescue EncodingError
        nil
      end
    end
  end
end
