require "bundler/gem_tasks"
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

desc 'Validate every document the specs render with the Open XML SDK (needs Docker)'
task :ooxml do
  dir = File.expand_path('tmp/ooxml', __dir__)

  rm_rf dir
  ENV['OOXML_DUMP_DIR'] = dir
  Rake::Task[:spec].invoke

  sh 'docker', 'build', '--quiet', '--tag', 'caracal-ooxml-validator', '.github/ooxml-validator'
  sh 'docker', 'run', '--rm', '--volume', "#{dir}:/docs:ro", 'caracal-ooxml-validator', '/docs'
end

