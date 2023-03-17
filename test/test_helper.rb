# typed: true
# frozen_string_literal: true

require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
ENV["RAILS_ENV"] = "test"

require "packwerk"

require "minitest/autorun"
require "minitest/focus"
require "mocha/minitest"
require "support/packwerk/application_fixture_helper"
require "support/packwerk/factory_helper"
require "support/stub_const"
require "support/rails_application_fixture_helper"
require "support/test_macro"
require "support/test_assertions"
require "support/yaml_file"
require "support/typed_mock"
require "support/packwerk/formatters/offenses_formatter_plain"

Minitest::Test.include(StubConst)
Minitest::Test.extend(TestMacro)
Minitest::Test.include(TestAssertions)

Mocha.configure do |c|
  c.stubbing_non_existent_method = :prevent
end
