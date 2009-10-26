require File.dirname(__FILE__) + '/../spec_helper.rb'

describe "Extensions" do
  before(:all) do
    @cr = CouchRest.new(COUCHHOST)
    @db = @cr.database(TESTDB)
    @db.delete! rescue nil
    @db = @cr.create_db(TESTDB) rescue nil
    @adb = @cr.database('couchrest-model-test')
    @adb.delete! rescue nil
    CouchSurfer::Model.default_database = CouchRest.database!('http://127.0.0.1:5984/couch_surfer-test')
    @des = CouchRest::Design.new
    @des.database = @db
    @des.name = "MyDesignDoc"
    @des.save
  end

  describe CouchRest::Database do
    it "should have a list method" do
      @db.should respond_to(:list)
    end
  end

  describe CouchRest::Document do
    it "should have a list method" do
      @des.should respond_to(:list)
    end
  end
end
