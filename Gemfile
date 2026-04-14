# frozen_string_literal: true

source("https://rubygems.org")
git_source(:github) { |repo_name| "https://github.com/#{repo_name}.git" }

gemspec

gem("rubydex", github: "Shopify/rubydex", branch: "04-14-use_bundle_gemfile_to_determine_if_we_need_a_debug_build")

# Specify the same dependency sources as the application Gemfile

gem("spring")
gem("rubocop-performance", require: false)
gem("rubocop-sorbet", require: false)
gem("mocha", require: false)
gem("rubocop-shopify", require: false)
gem("tapioca", require: false)
gem("railties")

gem("byebug")
gem("minitest-focus")
gem("minitest", "~> 5.0")

gem("m")
gem("rake")
gem("sorbet-static-and-runtime")
gem("zeitwerk")

# Ruby 4.0 removed ostruct from stdlib; yard/tapioca need it
gem("ostruct")
gem("mutex_m")
