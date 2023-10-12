# typed: true
# frozen_string_literal: true

# TODO: make better_html not require Rails
require "rails/railtie"

require "test_helper"

module Packwerk
  module Parsers
    class FactoryTest < Minitest::Test
      test "#for_path gives ruby parser for common Ruby paths" do
        assert_instance_of(Parsers::Ruby, factory.for_path("foo.rb").first)
        assert_instance_of(Parsers::Ruby, factory.for_path("relative/path/to/foo.ru").first)
        assert_instance_of(Parsers::Ruby, factory.for_path("foo.rake").first)
        assert_instance_of(Parsers::Ruby, factory.for_path("foo.builder").first)
        assert_instance_of(Parsers::Ruby, factory.for_path("in/repo/gem/foo.gemspec").first)
        assert_instance_of(Parsers::Ruby, factory.for_path("Gemfile").first)
        assert_instance_of(Parsers::Ruby, factory.for_path("some/path/Rakefile").first)
      end

      test "#for_path gives ERB parser for common ERB paths" do
        assert_instance_of(Parsers::Erb, factory.for_path("foo.html.erb").first)
        assert_instance_of(Parsers::Erb, factory.for_path("foo.md.erb").first)
        assert_instance_of(Parsers::Erb, factory.for_path("/sub/directory/foo.erb").first)
      end

      test "#for_path gives multiple parsers for matching paths" do
        fake_class_1 = Class.new do
          T.unsafe(self).include(Packwerk::FileParser)

          def match?(path:)
            /\.haml\Z/.match?(path)
          end
        end

        fake_class_2 = Class.new do
          T.unsafe(self).include(Packwerk::FileParser)

          def match?(path:)
            /\.haml\Z/.match?(path)
          end
        end

        factories = factory.for_path("foo.haml")
        assert_equal(2, factories.size)
        assert_instance_of(fake_class_1, factories[0])
        assert_instance_of(fake_class_2, factories[1])

        Packwerk::FileParser.remove(fake_class_1)
        Packwerk::FileParser.remove(fake_class_2)

        factories = factory.for_path("foo.haml")
        assert_equal(0, factories.size)
      end

      test "#for_path gives empty array for unknown path" do
        assert_empty(factory.for_path("not_a_ruby.rb.txt"))
        assert_empty(factory.for_path("some/path/rb"))
        assert_empty(factory.for_path("compoennts/foo/body.erb.html"))
      end

      private

      def factory
        Parsers::Factory.instance
      end
    end
  end
end
