# frozen_string_literal: true

require_relative "lib/packwerk/version"

Gem::Specification.new do |spec|
  spec.name          = "packwerk"
  spec.version       = Packwerk::VERSION
  spec.authors       = ["Shopify Inc."]
  spec.email         = ["gems@shopify.com"]

  spec.summary       = "Packages for applications based on the zeitwerk autoloader"

  spec.description   = <<~DESCRIPTION
    Sets package level boundaries between a specified set of ruby
    constants to minimize cross-boundary referencing and dependency.
  DESCRIPTION
  spec.homepage      = "https://github.com/Shopify/packwerk"
  spec.license       = "MIT"

  if spec.respond_to?(:metadata)
    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/Shopify/packwerk"
    spec.metadata["changelog_uri"] = "https://github.com/Shopify/packwerk/releases"
  end

  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.bindir = "exe"
  spec.executables << "packwerk"

  spec.files = Dir.chdir(__dir__) do
    %x(git ls-files -z).split("\x0").reject { |f| f.match(%r{^(test|spec|features|static)/}) }
  end
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.7"

  spec.add_dependency("activesupport", ">= 6.0")
  spec.add_dependency("bundler")
  spec.add_dependency("constant_resolver", ">= 0.2.0")
  spec.add_dependency("parallel")
  spec.add_dependency("sorbet-runtime", ">= 0.5.9914")
  spec.add_dependency("zeitwerk", ">= 2.6.1")

  # For Ruby parsing
  spec.add_dependency("ast")
  spec.add_dependency("parser")

  # For ERB parsing
  spec.add_dependency("better_html")

  spec.add_development_dependency("railties")
end
