begin
  require 'spec'
rescue LoadError
  require 'rubygems'
  gem 'rspec'
  require 'spec'
end

$:.unshift(File.dirname(__FILE__) + '/../lib')
require 'couch_surfer'

unless defined?(FIXTURE_PATH)
  FIXTURE_PATH = File.dirname(__FILE__) + '/fixtures' 
  SCRATCH_PATH = File.dirname(__FILE__) + '/tmp'

  COUCHHOST = "http://127.0.0.1:5984"
  TESTDB = 'couch_surfer-test'
end

def reset_test_db!
  cr = CouchRest.new(COUCHHOST)
  db = cr.database(TESTDB)
  db.delete! rescue nil
  db = cr.create_db(TESTDB) rescue nin
  db
end
#CouchSurfer::Model.default_database = CouchRest.database!('http://127.0.0.1:5984/couch_surfer-test')
