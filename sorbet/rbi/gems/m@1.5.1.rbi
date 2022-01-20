# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `m` gem.
# Please instead update this file by running `dev typecheck update`.

# typed: strict

module M
  class << self
    def run(argv); end
  end
end

class M::Executor
  def initialize(testable); end

  def execute; end

  private

  def runner; end
  def suites; end
  def testable; end
  def tests; end
end

class M::Frameworks
  def framework_runner; end

  private

  def minitest4?; end
  def minitest5?; end
  def test_unit?; end

  class << self
    def framework_runner; end
    def minitest4?; end
    def minitest5?; end
    def test_unit?; end
  end
end

class M::Parser
  def initialize(argv); end

  def parse; end

  private

  def argv; end
  def parse_options!(argv); end
  def testable; end
  def wildcard(type); end
end

class M::Runner
  def initialize(argv); end

  def run; end
end

module M::Runners
end

class M::Runners::Base
  def run(_test_arguments); end
  def suites; end
  def test_methods(suite_class); end
end

class M::Runners::Minitest4 < ::M::Runners::Base
  def run(test_arguments); end
  def suites; end
end

class M::Runners::Minitest5 < ::M::Runners::Base
  def run(test_arguments); end
  def suites; end
  def test_methods(suite_class); end
end

class M::Runners::TestUnit < ::M::Runners::Base
  def run(test_arguments); end
  def suites; end
  def test_methods(suite_class); end
end

class M::Runners::UnsupportedFramework < ::M::Runners::Base
  def run(_test_arguments); end
  def suites; end

  private

  def not_supported; end
end

class M::Testable
  def initialize(file = T.unsafe(nil), lines = T.unsafe(nil), recursive = T.unsafe(nil)); end

  def file; end
  def file=(_); end
  def lines; end
  def lines=(lines); end
  def recursive; end
  def recursive=(_); end
end

M::VERSION = T.let(T.unsafe(nil), String)
