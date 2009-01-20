require File.dirname(__FILE__) + '/../spec_helper.rb'

class Account
  include CouchSurfer::Model
  include CouchSurfer::Associations
  
  key_accessor :name
  
  has_many :employees, :view => {:name => :by_account_id_and_email, :query => lambda{ {:startkey => [id, nil], :endkey => [id, {}]} }}
  has_many :projects

end

class Project
  include CouchSurfer::Model
  include CouchSurfer::Associations
  
  key_accessor :name, :account_id
  
  belongs_to :account
  
  view_by :account_id
end


class Employee
  include CouchSurfer::Model
  include CouchSurfer::Associations
  
  key_accessor :email, :account_id
  belongs_to :account
  
  view_by :account_id, :email
  
end

describe CouchSurfer::Associations do
  before(:all) do
    db = CouchRest.database!('couch_surfer-test')
    db.delete!
    CouchSurfer::Model.default_database = CouchRest.database!('http://127.0.0.1:5984/couch_surfer-test')
    @account = Account.create(:name => "My Account")
    5.times do |i|
      Employee.create(:email => "foo#{i}@bar.com", :account_id => @account.id)
      Project.create(:name => "Project No. #{i}", :account_id => @account.id)
    end
  end
  
  describe "An employee" do
    it "should return it's users" do
      @other_employee = Employee.create(:email => "woo@war.com", :account_id => "ANOTHER_ACCOUNT_ID")
      @account.employees.length.should == 5
      @account.employees.should_not include(@other_employee)
    end
    
    it "should return it's parent account" do
      @employee = @account.employees.first
      @employee.account.should == @account
    end
  end
  
  describe "A project" do
    it "should return it's projects" do
      @other_project = Project.create(:name => "Another Project", :account_id => "ANOTHER_ACCOUNT_ID")
      @account.projects.length.should == 5
      @account.projects.should_not include(@other_project)
    end
    
    it "should return it's parent account" do
      @project = @account.projects.first
      @project.account.should == @account
    end
  end
end
