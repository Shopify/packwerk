# frozen_string_literal: true

source("https://rubygems.org")
git_source(:github) { |repo_name| "https://github.com/#{repo_name}.git" }

gemspec

# Specify the same dependency sources as the application Gemfile

gem("spring")
gem("constant_resolver", require: false)
gem("rubocop-performance", require: false)
gem("rubocop-sorbet", require: false)
gem("mocha", require: false)
gem("rubocop-shopify", require: false)
gem("rbi", "< 0.3.11", require: false) # rbi 0.3.11+ requires Ruby >= 3.3
gem("tapioca", require: false)
gem("railties")

gem("byebug")
gem("minitest-focus")
gem("minitest-mock")

gem("m")
gem("rake")
gem("sorbet-static")
gem("zeitwerk")
