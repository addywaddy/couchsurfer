require 'rake'
require File.join(File.expand_path(File.dirname(__FILE__)),'lib','couch_surfer')

begin
  require 'jeweler'
  Jeweler::Tasks.new do |s|
    s.name = "couch_surfer"
    s.date = "2009-01-22"
    s.summary = "ORM based on CouchRest::Model"
    s.email = "adam.groves@gmail.com"
    s.homepage = "http://github.com/addywaddy/couchsurfer"
    s.description = "CouchSurfer provides an ORM for CouchDB, as well as supporting association and validation declarations."
    s.has_rdoc = true
    s.authors = ["Adam Groves"]
    s.files = %w( LICENSE README.md Rakefile ) + 
      Dir["{lib,spec}/**/*"] - 
      Dir["spec/tmp"]
    s.extra_rdoc_files = %w( README.md LICENSE CHANGELOG.md )
    s.require_path = "lib"
    s.add_dependency("json", ">= 1.1.2")
    s.add_dependency("rest-client", ">= 0.8.2")
    s.add_dependency('couchrest', ">= 0.33")
  end
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = 'the-perfect-gem'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |t|
  t.libs << 'lib' << 'spec'
  t.spec_files = FileList['spec/**/*_spec.rb']
end

Spec::Rake::SpecTask.new(:rcov) do |t|
  t.libs << 'lib' << 'spec'
  t.spec_files = FileList['spec/**/*_spec.rb']
  t.rcov = true
end

begin
  require 'cucumber/rake/task'
  Cucumber::Rake::Task.new(:features)
rescue LoadError
  puts "Cucumber is not available. In order to run features, you must: sudo gem install cucumber"
end

task :default => :spec