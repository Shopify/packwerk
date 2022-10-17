# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"
require "active_support"
require "fileutils"

# Provides String#pluralize
require "active_support/core_ext/string"

require "zeitwerk"
loader = Zeitwerk::Loader.for_gem
loader.setup

module Packwerk
end
