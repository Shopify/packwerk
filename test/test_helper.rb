# typed: ignore
# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
ROOT = Pathname.new(__dir__).join("..").expand_path

require "constant_resolver"
require "packwerk"

require "minitest/autorun"
require "minitest/focus"
require "mocha/minitest"
require "support/test_macro"
require "support/test_assertions"
require "support/fixture_helper"
require "support/rails_fixture_helper"

Minitest::Test.extend(TestMacro)
Minitest::Test.include(TestAssertions)

Mocha.configure do |c|
  c.stubbing_non_existent_method = :prevent
end
