CouchSurfer - CouchDB ORM
=========================
---
Description
-----------
CouchSurfer is an extraction of CouchRest::Model from the excellent [CouchRest](http://github.com/jchris/couchrest/ "CouchRest") gem by J. Chris Anderson. In addition, it provides association and validation methods.

Associations
------------
CouchSurfer provides the following 4 association kinds:

 - `belongs_to`
 - `has_many`
 - `has_many :inline`; and
 - `has_many :through`

All association kinds take an optional `:class_name` option should you want your association to be named differently to the associated model.

    class Page
      …
      belongs_to :owner, :class_name => :user
      …
    end
    
    page = Page.create(…)
    page.owner # returns an instance of user
    
The `belongs_to` associations accept two additional options - `:view` and `query`, enabling you to customise your associations to fit your needs. You must explicitly declare the view on the child model for associations to work

**Example 1: basic**

    class User
      …
      has_many :pages
      …
    end
    
    class Page
      …
      view_by :user_id
      …
    end
    
    user = User.create(…)
    10.times {Page.create(…, :user_id => user.id)}
    user.pages
    

**Example 2: with options**

    class Account
      …
      has_many :employees,
          :class_name, :user,
          :view  => :by_account_id_and_email,
          :query => lambda { {:startkey => [account_id, nil], :endkey => [account_id, {}]}   }
      …
    end

    class User
      …
      view_by :account_id, :email # see validation examples below
      …
    end

    account = Acccount.create(…)
    10.times {User.create(…, :account_id => acount.id)}
    account.employees
    
**Example 2: :through**

    class Account
      …
      has_many :projects,
          :through => :memberships
      …
    end

    class Membership
      …
      view_by :account_id
      …
    end
    
    class Project
      …
      view_by :account_id, :email # see validation examples below
      …
    end

    account = Acccount.create(…)
    10.times do
      p = Project.create(…)
      Membership.create(…, :account_id => account.id, :project_id => p.id)
    end
    account.projects
    
**Note on HasManyThrough**

With reference to the above example, HasManyThrough works by retrieving all memberships associated with the account, collecting their ids and running a [bulk retrieval](http://wiki.apache.org/couchdb/HTTP_view_API "Query Options") on the Project.all view, which is implicitly created for all models and, as of 0.0.4, emits it's id (see CHANGELOG).

*Caveats*

  - Sorting needs to be done client side
  - The results do not contain any extra information that may be present on the ':through' model.

Validations
-----------
Validations, with the exception of `validates_uniqueness_of`, have been implemented using the [Validatable](http://github.com/jrun/validatable/ "Validatable") gem.

**Example**

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
      validates_uniqueness_of :name
      
      # Uses a custom view and key for uniqueness within a specific scope
      validates_uniqueness_of :email,
          :view => :by_account_id_and_email,
          :query => lambda{ {:key => [account_id, email]} },
          :message => "The email address for this account is taken"
  
    end


Please check out the specs as well :)

Next
----
  - Error handling
  - association methods with arguments:
    `@account.projects(:limit => 2, :offset => 1)`
