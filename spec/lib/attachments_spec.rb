require File.dirname(__FILE__) + '/../spec_helper.rb'

class Person
  include CouchSurfer::Model
  include CouchSurfer::Attachments

  key_accessor :name, :email

end

describe CouchSurfer::Attachments do
  before(:all) do
    db = CouchRest.database!('couch_surfer-test')
    db.delete!
    CouchSurfer::Model.default_database = CouchRest.database!('http://127.0.0.1:5984/couch_surfer-test')
  end

  before do
    @person = Person.create(:name => "John", :email => "john@mail.com")
  end

  describe "attaching a file" do
    it "should return true" do
      @person.put_attachment("couchdb.png", open_fixture("attachments/couchdb.png")).should be_true
    end

    it "should not escape spaces" do
      @person.put_attachment("couch db.png", open_fixture("attachments/couchdb.png")).should be_true
      @person.reload["_attachments"].keys.should include "couch db.png"
    end

    it "should not store filenames beginning with an underscore" do
      lambda{ @person.put_attachment("_couch db.png", open_fixture("attachments/couchdb.png")) }.should raise_error RestClient::RequestFailed
    end

    it "should not store filenames which are non-utf8" do
      lambda{ @person.put_attachment("®#†π¶®¥π€.png", open_fixture("attachments/couchdb.png")) }.should raise_error RestClient::RequestFailed
    end

    it "should raise an exception if the record is not yet saved" do
      person = Person.new(:name => "John", :email => "john@mail.com")
      lambda {person.put_attachment("couchdb.png", open_fixture("attachments/couchdb.png"))}.should raise_error(ArgumentError)
    end
  end

  describe "fetching a file" do
    it "should return the file" do
      @person.put_attachment("couchdb.png", open_fixture("attachments/couchdb.png")).should be_true
      @person.fetch_attachment("couchdb.png").size.should >= 3000
    end

    it "should raise an exception if the record is not yet saved" do
      person = Person.new(:name => "John", :email => "john@mail.com")
      lambda {person.fetch_attachment("couchdb.png")}.should raise_error(ArgumentError)      
    end
  end

  describe "deleting a file" do
    it "should return true" do
      @person.put_attachment("couchdb.png", open_fixture("attachments/couchdb.png")).should be_true
      @person.delete_attachment("couchdb.png").should be_true
      lambda {@person.fetch_attachment("couchdb.png")}.should raise_error(RestClient::ResourceNotFound)
    end
  end
end