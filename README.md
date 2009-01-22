CouchSurfer
===========

Description
-----------
CouchSurfer is an extraction of CouchRest::Model from the excellent [CouchRest](http://github.com/jchris/couchrest/ "CouchRest") gem by J. Chris Anderson.

Features
--------
- ORM (Extracted from CouchRest::Model)
- Associations
  - `has_ many`
  - `belongs_to`

- Validations
  - All validations from the [Validatable](http://github.com/jrun/validatable/ "Validatable") gem
  - `validates_uniqueness_of`

Examples
--------
    class Account
      include CouchSurfer::Model
      include CouchSurfer::Associations
  
      key_accessor :name
      
      # Will use the Project.by_account_id view with {:key => account_instance.id}
      has_many :projects
      
      # Uses a custom view and key
      has_many :employees, :view => {:name => :by_account_id_and_email, 
          :query => lambda{ {:startkey => [id, nil], :endkey => [id, {}]} }}

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
      include CouchSurfer::Validations
  
      key_accessor :email, :account_id
      belongs_to :account
  
      view_by :account_id, :email
      view_by :name

      validates_presence_of :name
      validates_format_of   :email, 
        :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
      validates_length_of :postcode, :is => 7, :message => "not the correct length"
      
      # Will use the Employee.by_name view with {:key => employee_instance.name}
      validates_uniqueness_of :name, :message => "No two Beatles have the same name"
      
      # Uses a custom view and key
      validates_uniqueness_of :email, :view => {:name => :by_account_id_and_email,
        :query => lambda{ {:key => [account_id, email]} }}, :message => "Already taken!"
  
    end
    
Please check out the specs as well :)