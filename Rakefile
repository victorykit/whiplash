require "bundler/gem_tasks"
require "rspec/core/rake_task"

desc "Default: specs"
task default: :spec

desc "Run specs"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = "./spec/**/*_spec.rb" # don't need this, it's default.
end
