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
gem("tapioca", require: false)

group :development do
  gem("byebug", require: false)
  gem("minitest-focus", require: false)

  gem("m")
  gem("rake")
  gem("sorbet-static-and-runtime")
  gem("zeitwerk")
end
