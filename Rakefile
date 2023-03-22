# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"].reject do |file|
    file.include?("test/loading/")
  end
  t.warning = false
end

Rake::TestTask.new("test:loading") do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/loading/**/*_test.rb"]
  t.warning = false
end

task(default: :test)
