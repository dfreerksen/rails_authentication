# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec) do |t|
  t.exclude_pattern = "spec/requests/**/*_spec.rb"
end

namespace :spec do
  desc "Run generator specs only"
  RSpec::Core::RakeTask.new(:generators) do |t|
    t.pattern = "spec/generators/**/*_spec.rb"
  end

  desc "Run request specs against spec/dummy (run `rake dummy:prepare` first)"
  RSpec::Core::RakeTask.new(:requests) do |t|
    t.pattern = "spec/requests/**/*_spec.rb"
  end
end

namespace :dummy do
  desc "Regenerate spec/dummy by running the real generator against a fresh Rails app"
  task :prepare do
    sh "bin/prepare_dummy"
  end
end

task default: :spec
