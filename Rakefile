require 'rake'
require "rake/rdoctask"
require 'rake/gempackagetask'
require File.join(File.expand_path(File.dirname(__FILE__)),'lib','couch_surfer')


begin
  require 'spec/rake/spectask'
rescue LoadError
  puts <<-EOS
To use rspec for testing you must install rspec gem:
    gem install rspec
EOS
  exit(0)
end

spec = Gem::Specification.new do |s|
  s.name = "couch_surfer"
  s.version = CouchSurfer::VERSION
  s.date = "2009-01-22"
  s.summary = "ORM based on CouchRest::Model"
  s.email = "jchris@apache.org"
  s.homepage = "http://github.com/addywaddy/couchsurfer"
  s.description = "CouchSurfer provides an ORM for CouchDB, as well as supporting association and validation declarations."
  s.has_rdoc = true
  s.authors = ["Adam Groves"]
  s.files = %w( LICENSE README.md Rakefile THANKS.md ) + 
    Dir["{lib,spec}/**/*"] - 
    Dir["spec/tmp"]
  s.extra_rdoc_files = %w( README.md LICENSE THANKS.md )
  s.require_path = "lib"
  s.add_dependency("json", ">= 1.1.2")
  s.add_dependency("rest-client", ">= 0.5")
  s.add_dependency('jchris-couchrest', ">= 0.12.2")
end


desc "create .gemspec file (useful for github)"
task :gemspec do
  filename = "#{spec.name}.gemspec"
  File.open(filename, "w") do |f|
    f.puts spec.to_ruby
  end
end

desc "Run all specs"
Spec::Rake::SpecTask.new('spec') do |t|
	t.spec_files = FileList['spec/**/*_spec.rb']
end

desc "Print specdocs"
Spec::Rake::SpecTask.new(:doc) do |t|
	t.spec_opts = ["--format", "specdoc"]
	t.spec_files = FileList['spec/*_spec.rb']
end

desc "Generate the rdoc"
Rake::RDocTask.new do |rdoc|
  files = ["README.rdoc", "LICENSE", "lib/**/*.rb"]
  rdoc.rdoc_files.add(files)
  rdoc.main = "README.rdoc"
  rdoc.title = "CouchRest: Ruby CouchDB, close to the metal"
end

desc "Run the rspec"
task :default => :spec

