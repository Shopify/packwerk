# typed: true
# frozen_string_literal: true

require "test_helper"

module Packwerk
  class CheckerTest < Minitest::Test
    include FactoryHelper

    test "#find is correctly able to find the right checker" do
      found_checker = Checker.find('dependency')
      assert T.unsafe(found_checker).is_a?(Packwerk::ReferenceChecking::Checkers::DependencyChecker)
    end
  end
end
