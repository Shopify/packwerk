# typed: strict

# Prism::Translation::Parser::Builder was introduced in prism 1.4.0. The
# committed Gemfile.lock pins prism to 0.27.0 (constrained by rbi gem), so this
# shim declares the class for Sorbet so that static type checking passes without
# requiring a lockfile bump.
class Prism::Translation::Parser::Builder < ::Parser::Builders::Default; end
