require File.dirname(__FILE__) + '/../spec_helper.rb'

class Account
  include CouchSurfer::Model
  include CouchSurfer::Associations

  key_accessor :name

  has_many :employees,
      :view => :by_account_id_and_role,
      :query => lambda{ {:startkey => [id, nil], :endkey => [id, {}]} }

  has_many :programmers, :class_name => :employee,
      :view => :by_account_id_and_role,
      :query => lambda{ {:startkey => [id, "Programmer"], :endkey => [id, "Programmer"]} }

  has_many :projects

end

class Project
  include CouchSurfer::Model
  include CouchSurfer::Associations
  
  key_accessor :name, :account_id
  
  belongs_to :account
  has_many :members, :through => :memberships, :class_name => :employee
  
  view_by :account_id
  view_by :id
end

class Membership
  include CouchSurfer::Model
  include CouchSurfer::Associations
  
  key_accessor :project_id, :employee_id
  belongs_to :project
  belongs_to :employee
  
  view_by :project_id
  view_by :employee_id
end


class Employee
  include CouchSurfer::Model
  include CouchSurfer::Associations
  
  key_accessor :email, :account_id, :role
  
  belongs_to :employer, :class_name => :account
  has_many :shirts, :inline => true
  has_many :projects, :through => :memberships
  
  view_by :account_id, :role
  
end

class Shirt
  include CouchSurfer::Model
  include CouchSurfer::Associations
  
  key_accessor :color
end

describe CouchSurfer::Associations do
  before(:all) do
    db = CouchRest.database!('couch_surfer-test')
    db.delete!
    CouchSurfer::Model.default_database = CouchRest.database!('http://127.0.0.1:5984/couch_surfer-test')
    @account = Account.create(:name => "My Account")
    2.times do |i|
      Employee.create(:email => "foo#{i+1}@bar.com", :account_id => @account.id, :role => "Programmer")
      Employee.create(:email => "foo#{i+3}@bar.com", :account_id => @account.id, :role => "Engineer")
      Project.create(:name => "Project No. #{i}", :account_id => @account.id)
    end
    @employee = @account.employees.first
    @project = @account.projects.first
  end
  
  describe "belongs_to" do
    it "should return it's parent" do
      @project.account.should == @account
    end
    
    it "should take the class_name into consideration" do
      @employee.employer.should == @account
    end
  end
  
  describe "has_many" do
    describe "vanilla" do
      it "should return it's children" do
        @account.employees.length.should == 4
        @account.employees.map{|employee| employee.email}.sort.should == ["foo1@bar.com", "foo2@bar.com", "foo3@bar.com", "foo4@bar.com"]
      end
    end
    
    describe ":class_name" do
      it "should return it's children" do
        @account.programmers.length.should == 2
      end
    end
    describe ":inline" do
      before(:all) do
        @employee.shirts.clear
        @blue_shirt = Shirt.create(:color => "White")
        @pink_shirt = Shirt.create(:color => "Pink")
        @employee.shirts << {:color => "Blue"}
        @employee.shirts << @blue_shirt
        @employee.save
        @employee = Employee.get(@employee.id)
        @employee.shirts << @pink_shirt
        @employee.save
      end
      it "should return it's children" do
        employee = Employee.get(@employee.id)
        employee.shirts.each do |shirt|
          shirt.should be_kind_of(Shirt)
        end
        employee.shirts.map{|shirt| shirt.color}.should == %w(Blue White Pink)
      end

      it "should have a delete method" do
        employee = Employee.get(@employee.id)
        employee.shirts.delete(@pink_shirt)
        employee.save
        employee = Employee.get(@employee.id)
        employee.shirts.map{|shirt| shirt.color}.should == %w(Blue White)
      end
      
      it "should have an append method" do
        employee = Employee.get(@employee.id)
        employee.shirts << {:color => "Black"}
        employee.save
        employee = Employee.get(@employee.id)
        employee.shirts.map{|shirt| shirt.color}.should == %w(Blue White Black)
      end

    end
    
    describe ":through" do
      it "should return it's 'through' children" do
        @employee.memberships.should be_empty
      end
      
      it "should return it's children" do
        3.times do |i|
          p = Project.create(:name => "Project with Invitations No. #{i}", :account_id => @account.id)
          Membership.create(:employee_id => @employee.id, :project_id => p.id)
        end
        
        7.times do |i|
          e = Employee.create(:email => "bar#{i}@bar.com", :account_id => @account.id)
          Membership.create(:employee_id => e.id, :project_id => @project.id)
        end
        
        @employee.memberships.size.should == 3
        @employee.projects.size.should == 3
        @project.memberships.size.should == 7
        @project.members.size.should == 7
      end
    end
  end
end
