require File.dirname(__FILE__) + '/../spec_helper.rb'

module CouchSurfer
  describe "Database" do
    before do
      Database.destroy!(:name => "couch_surfer_testdb") rescue nil
    end

    describe "creating a database" do

      it "should return an OK status" do
        Database.create(:name => "couch_surfer_testdb")['ok'].should be_true
      end

      it "should have errors if the DB already exists" do
        Database.create(:name => "couch_surfer_testdb")['ok'].should be_true
        lambda{ Database.create!(:name => "couch_surfer_testdb") }.should raise_error(Database::AlreadyExists)
      end

    end

    describe "deleting a database" do
      before do
        Database.create!(:name => "couch_surfer_testdb")
      end

      it "should return an OK status" do
        Database.destroy(:name => "couch_surfer_testdb")['ok'].should be_true
      end

      it "should raise an error if the DB doesn't exists" do
        Database.destroy(:name => "couch_surfer_testdb")['ok'].should be_true
        lambda{ Database.destroy!(:name => "couch_surfer_testdb") }.should raise_error(Database::NotFound)
      end

    end

    describe "listing databases" do
      after do
        4.times { |i| Database.destroy!(:name => "couch_surfer_testdb#{i+1}") rescue nil}
      end

      it "should return an array of databases" do
        4.times { |i| Database.create!(:name => "couch_surfer_testdb#{i+1}")}
        (Database.list & ["couch_surfer_testdb1", "couch_surfer_testdb2", "couch_surfer_testdb3", "couch_surfer_testdb4"]).size.should == 4
      end

    end

    describe "using a database" do
      before do
        Database.create!(:name => "couch_surfer_testdb")
      end

      it "should return a hash containing information about the database" do
        db = Database.use(:name => "couch_surfer_testdb")
        db.db_name.should == "couch_surfer_testdb"
        db.doc_count.should == 0
      end

      it "should raise an error if the DB doesn't exists" do
        lambda{ Database.use!(:name => "non_existant_db") }.should raise_error(Database::NotFound)
      end

    end

    describe "saving documents" do
      before do
        p "before create"
        Database.create!(:name => "couch_surfer_testdb")
        p "before use"
        @db = Database.use(:name => "couch_surfer_testdb")
      end

      it "should return a hash containg information about the created document" do
        doc = {:name => "John", :surname => "Lennon"}
        response = @db.save_doc(doc)
        response['ok'].should be_true
        response['id'].should == "FOO"
        response['rev'].should_not be_empty
      end

      it "should raise an error if the document in invalid" do
        doc = "INVALID BODY"
        lambda{ p @db.save_doc(doc) }.should raise_error(Database::NonJsonDocument)
      end

    end

  end
end
