# typed: true
# frozen_string_literal: true

# TODO: make better_html not require Rails
require "rails/railtie"

require "test_helper"

module Packwerk
  module Parsers
    class FactoryTest < Minitest::Test
      test "#for_path gives ruby parser for common Ruby paths" do
        assert_instance_of(Parsers::Ruby, factory.for_path("foo.rb"))
        assert_instance_of(Parsers::Ruby, factory.for_path("relative/path/to/foo.ru"))
        assert_instance_of(Parsers::Ruby, factory.for_path("foo.rake"))
        assert_instance_of(Parsers::Ruby, factory.for_path("foo.builder"))
        assert_instance_of(Parsers::Ruby, factory.for_path("in/repo/gem/foo.gemspec"))
        assert_instance_of(Parsers::Ruby, factory.for_path("Gemfile"))
        assert_instance_of(Parsers::Ruby, factory.for_path("some/path/Rakefile"))
      end

      test "#for_path gives ERB parser for common ERB paths" do
        assert_instance_of(Parsers::Erb, factory.for_path("foo.html.erb"))
        assert_instance_of(Parsers::Erb, factory.for_path("foo.md.erb"))
        assert_instance_of(Parsers::Erb, factory.for_path("/sub/directory/foo.erb"))
      end

      test "#for_path gives custom parser for matching paths" do
        fake_class = Class.new do
          T.unsafe(self).include(Packwerk::Parser)

          def match?(path:)
            /\.slim\Z/.match?(path)
          end
        end

        assert_instance_of(fake_class, factory.for_path("foo.html.slim"))
        assert_instance_of(fake_class, factory.for_path("foo.md.slim"))
        assert_instance_of(fake_class, factory.for_path("/sub/directory/foo.slim"))
      end

      test "#for_path gives nil for unknown path" do
        assert_nil(factory.for_path("not_a_ruby.rb.txt"))
        assert_nil(factory.for_path("some/path/rb"))
        assert_nil(factory.for_path("compoennts/foo/body.erb.html"))
      end

      private

      def factory
        Parsers::Factory.instance
      end
    end
  end
end
