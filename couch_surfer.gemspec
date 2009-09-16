# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{couch_surfer}
  s.version = "0.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Adam Groves"]
  s.date = %q{2009-08-12}
  s.description = %q{CouchSurfer provides an ORM for CouchDB, as well as supporting association and validation declarations.}
  s.email = %q{adam.groves@gmail.com}
  s.extra_rdoc_files = [
    "CHANGELOG.md",
     "LICENSE",
     "README.md"
  ]
  s.files = [
    "LICENSE",
     "README.md",
     "Rakefile",
     "lib/couch_surfer.rb",
     "lib/couch_surfer/associations.rb",
     "lib/couch_surfer/attachments.rb",
     "lib/couch_surfer/model.rb",
     "lib/couch_surfer/query.rb",
     "lib/couch_surfer/validations.rb",
     "lib/couchrest/extensions.rb",
     "spec/fixtures/attachments/README",
     "spec/fixtures/attachments/couchdb.png",
     "spec/fixtures/attachments/test.html",
     "spec/fixtures/views/lib.js",
     "spec/fixtures/views/test_view/lib.js",
     "spec/fixtures/views/test_view/only-map.js",
     "spec/fixtures/views/test_view/test-map.js",
     "spec/fixtures/views/test_view/test-reduce.js",
     "spec/lib/associations_spec.rb",
     "spec/lib/attachments_spec.rb",
     "spec/lib/extensions_spec.rb",
     "spec/lib/model_spec.rb",
     "spec/lib/query_spec.rb",
     "spec/lib/validations_spec.rb",
     "spec/spec.opts",
     "spec/spec_helper.rb"
  ]
  s.homepage = %q{http://github.com/addywaddy/couchsurfer}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.4}
  s.summary = %q{ORM based on CouchRest::Model}
  s.test_files = [
    "spec/lib/associations_spec.rb",
     "spec/lib/attachments_spec.rb",
     "spec/lib/extensions_spec.rb",
     "spec/lib/model_spec.rb",
     "spec/lib/query_spec.rb",
     "spec/lib/validations_spec.rb",
     "spec/spec_helper.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<json>, [">= 1.1.2"])
      s.add_runtime_dependency(%q<rest-client>, [">= 0.8.2"])
      s.add_runtime_dependency(%q<jchris-couchrest>, [">= 0.12.2"])
    else
      s.add_dependency(%q<json>, [">= 1.1.2"])
      s.add_dependency(%q<rest-client>, [">= 0.8.2"])
      s.add_dependency(%q<jchris-couchrest>, [">= 0.12.2"])
    end
  else
    s.add_dependency(%q<json>, [">= 1.1.2"])
    s.add_dependency(%q<rest-client>, [">= 0.8.2"])
    s.add_dependency(%q<jchris-couchrest>, [">= 0.12.2"])
  end
end
