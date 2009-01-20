require File.dirname(__FILE__) + '/../spec_helper.rb'


class User
  include CouchSurfer::Model
  include CouchSurfer::Validations
  
  
  key_accessor :name, :email, :postcode, :account_id
  
  view_by :account_id, :email
  view_by :name
  
  validates_presence_of :name
  validates_format_of   :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
  validates_length_of   :postcode, :is => 7, :message => "not the correct length"
  validates_uniqueness_of :name, :message => "No two Beatles have the same name"
  validates_uniqueness_of :email, :view => {:name => :by_account_id_and_email, :query => lambda{ {:key => [account_id, email]} }}, :message => "Already taken!"
end


describe CouchSurfer::Validations do
  before(:all) do
    db = CouchRest.database!('couch_surfer-test')
    db.delete!
    CouchSurfer::Model.default_database = CouchRest.database!('http://127.0.0.1:5984/couch_surfer-test')
  end
  before(:each) do
    @user = User.new(:name => nil, :email => "foo.bar.com", :postcode => "WD2", :account_id => 1)
  end
  describe "Validations" do
    before(:each) do
      @user.save.should be_false      
    end
    describe "presence_of" do
      it "should display relevant error messages" do
        @user.errors.on(:name).should == "can't be empty"
      end
    end
    describe "format_of" do
      it "should display relevant errors messages" do
        @user.errors.on(:email).should == "is invalid"
      end
    end
    describe "length_of" do
      it "should check the length of the field" do
        @user.errors.on(:postcode).should == "not the correct length"
      end
    end
    describe "uniqueness_of" do
      before(:all) do
        paul = User.new(:name => "Paul", :email => "paul@beatles.com", :postcode => "WD2 4WF", :account_id => 1)
        paul.save.should be_true
        @user_with_invalid_email = User.new(:name => "John", :email => "paul@beatles.com", :postcode => "WD2 4WF", :account_id => 1)
        @user_with_invalid_name = User.new(:name => "Paul", :email => "george@beatles.com", :postcode => "WD2 4WF", :account_id => 1)
      end
      
      describe "basic" do
        it "should display relevant errors messages" do
          @user_with_invalid_name.save.should be_false
          @user_with_invalid_name.errors.on(:name).should == "No two Beatles have the same name"
        end
        
        it "should save if the user is unique within the scope" do
          @user_with_invalid_name.name = "George"
          @user_with_invalid_name.save.should be_true
        end
      end
      
      describe "with scope" do
        it "should display relevant error messages" do
          @user_with_invalid_email.save.should be_false
          @user_with_invalid_email.errors.on(:email).should == "Already taken!"
        end
        
        it "should save if the user is unique within the scope" do
          @user_with_invalid_email.email = "george@beatles.com"
          @user_with_invalid_email.save.should be_true
        end
      end

    end
    describe "when valid" do
      it "should save the document" do
        @user.name = "Foo"
        @user.postcode = "WD2 3AX"
        @user.email = "foo2@bar.com"
        @user.save.should be_true        
      end
    end
  end

end