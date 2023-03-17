# typed: true
# frozen_string_literal: true

require "pathname"

ROOT = Pathname.new(__dir__).join("..").expand_path
ENV["RAILS_ENV"] = "test"

require "minitest/autorun"
require "minitest/focus"
require "mocha/minitest"
require "active_support/testing/isolation"
require "support/test_macro"
require "support/test_assertions"

Minitest::Test.extend(TestMacro)
Minitest::Test.include(TestAssertions)
