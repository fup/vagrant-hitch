require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

task :default => [:test]

desc "run all functional specs in this ruby environment"
RSpec::Core::RakeTask.new(:test) do |t|
  t.pattern = 'spec/*_spec.rb'

  t.rspec_opts = [ 
    '--format', 'documentation',
    #  This is only really needed once - we can remove it from all the specs
    #'--require ./spec/spec_helper.rb',
    '--color',
  ]
end

desc "run the specs through all the supported rubies"
task :rubies do
  system("rvm 1.8.7-p370,1.9.3-p194 do rake test")
end

desc "set up all ruby environments"
namespace :bootstrap do
  task :all_rubies do
  end
end

