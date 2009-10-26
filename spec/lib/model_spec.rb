require File.dirname(__FILE__) + '/../spec_helper.rb'

class Basic
  include CouchSurfer::Model
end

class BasicWithValidation
  include CouchSurfer::Model

  before :create, :validate
  before :update, :change_name
  key_accessor :name

  def validate
    throw(:halt, false) unless name
  end

  def change_name
    self.name = "Bar"
  end
end

class Article
  include CouchSurfer::Model
  unique_id :slug

  view_by :date, :descending => true
  view_by :user_id, :date

  view_by :tags,
    :map =>
      "function(doc) {
        if (doc['couchrest-type'] == 'Article' && doc.tags) {
          doc.tags.forEach(function(tag){
            emit(tag, 1);
          });
        }
      }",
    :reduce =>
      "function(keys, values, rereduce) {
        return sum(values);
      }"

  lists :names =>
  "function(head, req){
    var row;
    while(row = getRow()) {
      send(row.doc.title);
    }
  }"

  key_writer :date
  key_reader :slug #, :created_at, :updated_at
  key_accessor :title, :tags

  timestamps!

  before(:save, :generate_slug_from_title)
  def generate_slug_from_title
    self['slug'] = title.downcase.gsub(/[^a-z0-9]/,'-').squeeze('-').gsub(/^\-|\-$/,'') if new_document?
  end
end

class WithTemplateAndUniqueID
  include CouchSurfer::Model

  unique_id do |model|
    model['important-field']
  end
  set_default({
    :preset => 'value',
    'more-template' => [1,2,3]
  })
  key_accessor :preset
  key_accessor :has_no_default
end

class Question
  include CouchSurfer::Model

  key_accessor :q, :a
end

class Person
  include CouchSurfer::Model

  key_accessor :name
  def last_name
    name.last
  end
end

class Course
  include CouchSurfer::Model

  key_accessor :title
  cast :questions, :as => ['Question']
  cast :professor, :as => 'Person'
  cast :final_test_at, :as => 'Time'
  view_by :title
  view_by :dept, :ducktype => true
end

class Event
  include CouchSurfer::Model

  key_accessor :subject, :occurs_at

  cast :occurs_at, :as => 'Time'
end

describe CouchSurfer::Model do
  before(:all) do
    @cr = CouchRest.new(COUCHHOST)
    @db = @cr.database(TESTDB)
    @db.delete! rescue nil
    @db = @cr.create_db(TESTDB) rescue nil
    @adb = @cr.database('couchrest-model-test')
    @adb.delete! rescue nil
    CouchSurfer::Model.default_database = CouchRest.database!('http://127.0.0.1:5984/couch_surfer-test')
  end

  describe "setting the database" do
    it "should use the default database" do
      Basic.database.info['db_name'].should == 'couch_surfer-test'
    end

    it "should be able to overwrite the default" do
      Basic.use_database CouchRest.database!('http://127.0.0.1:5984/couch_surfer-custom')
      Basic.database.info['db_name'].should == 'couch_surfer-custom'
    end
  end

  describe "a new model" do
    it "should be a new_record" do
      Basic.new.should be_a_new_record
    end
  end

  describe "a model with key_accessors" do
    it "should allow reading keys" do
      @art = Article.new(:title => 'My Article Title')
      @art.title.should == 'My Article Title'
    end
    it "should allow setting keys" do
      @art = Article.new(:title => 'My Article Title')
      @art.title = 'My New Article Title'
      @art.title.should == 'My New Article Title'
    end
  end

  describe "a model with key_writers" do
    it "should allow setting keys" do
      @art = Article.new
      t = Time.now
      @art.date = t
      @art.attributes[:date].should == t
    end
    it "should not allow reading keys" do
      @art = Article.new
      t = Time.now
      @art.date = t
      lambda{@art.date}.should raise_error
    end
  end

  describe "a model with key_readers" do
    it "should allow reading keys" do
      @art = Article.new(:slug => "my-slug")
      @art.slug.should == 'my-slug'
    end
    it "should not allow setting keys" do
      @art = Article.new
      lambda{@art.slug = 'My Article Title'}.should raise_error
    end
  end

  describe "update attributes without saving" do
    before(:each) do
      a = Article.get "big-bad-danger" rescue nil
      a.destroy if a
      @art = Article.new(:title => "big bad danger")
      @art.save
    end
    it "should work for attribute= methods" do
      @art['title'].should == "big bad danger"
      @art.update_attributes(:date => Time.now, :title => "super danger")
      @art['title'].should == "super danger"
    end

    it "should flip out if an attribute= method is missing" do
      lambda {
        @art.update_attributes('slug' => "new-slug", :title => "super danger")
      }.should raise_error
    end

    it "should not change other attributes if there is an error" do
      lambda {
        @art.update_attributes('slug' => "new-slug", :title => "super danger")
      }.should raise_error
      @art['title'].should == "big bad danger"
    end
  end

  describe "update attributes" do
    before(:each) do
      a = Article.get "big-bad-danger" rescue nil
      a.destroy if a
      @art = Article.new(:title => "big bad danger")
      @art.save
    end
    it "should save" do
      @art['title'].should == "big bad danger"
      @art.update_attributes('date' => Time.now, :title => "super danger")
      loaded = Article.get @art.id
      loaded['title'].should == "super danger"
    end
  end

  describe "a model with template values" do
    before(:all) do
      @tmpl = WithTemplateAndUniqueID.new
      @tmpl2 = WithTemplateAndUniqueID.new(:preset => 'not_value', 'important-field' => '1')
    end
    it "should have fields set when new" do
      @tmpl.preset.should == 'value'
    end
    it "shouldn't override explicitly set values" do
      @tmpl2.preset.should == 'not_value'
    end
    it "shouldn't override existing documents" do
      @tmpl2.save
      tmpl2_reloaded = WithTemplateAndUniqueID.get(@tmpl2.id)
      @tmpl2.preset.should == 'not_value'
      tmpl2_reloaded.preset.should == 'not_value'
    end

    it "shouldn't fill in existing documents" do
      @tmpl2.save
      # If user adds a new default value, shouldn't be retroactively applied to
      # documents upon fetching
      WithTemplateAndUniqueID.set_default({:has_no_default => 'giraffe'})

      tmpl2_reloaded = WithTemplateAndUniqueID.get(@tmpl2.id)
      @tmpl2.has_no_default.should be_nil
      tmpl2_reloaded.has_no_default.should be_nil
      WithTemplateAndUniqueID.new.has_no_default.should == 'giraffe'
    end
  end

  describe "getting a model" do
    before(:all) do
      @art = Article.new(:title => 'All About Getting')
      @art.save
    end
    it "should load and instantiate it" do
      foundart = Article.get @art.id
      foundart.title.should == "All About Getting"
    end

    it "should raise an error if the document can't be found" do
      lambda {Article.get("THIS DONT EXIST")}.should raise_error(CouchSurfer::RecordNotFound)
    end
  end

  describe "getting a model with a subobjects array" do
    before(:all) do
      course_doc = {
        "title" => "Metaphysics 200",
        "questions" => [
          {
            "q" => "Carve the ___ of reality at the ___.",
            "a" => ["beast","joints"]
          },{
            "q" => "Who layed the smack down on Leibniz's Law?",
            "a" => "Willard Van Orman Quine"
          }
        ]
      }
      r = Course.database.save_doc course_doc
      @course = Course.get r['id']
    end
    it "should load the course" do
      @course.title.should == "Metaphysics 200"
    end
    it "should instantiate them as such" do
      @course["questions"][0].a[0].should == "beast"
    end
  end

  describe "finding all instances of a model" do
    before(:all) do
      WithTemplateAndUniqueID.new('important-field' => '1').save
      WithTemplateAndUniqueID.new('important-field' => '2').save
      WithTemplateAndUniqueID.new('important-field' => '3').save
      WithTemplateAndUniqueID.new('important-field' => '4').save
    end
    it "should make the design doc" do
      WithTemplateAndUniqueID.all
      WithTemplateAndUniqueID.all
      d = WithTemplateAndUniqueID.design_doc
      d['views']['all']['map'].should include('WithTemplateAndUniqueID')
    end
    it "should find all" do
      rs = WithTemplateAndUniqueID.all
      rs.length.should == 4
    end
  end

  describe "finding the first instance of a model" do
    before(:each) do
      @db = reset_test_db!
      WithTemplateAndUniqueID.new('important-field' => '1').save
      WithTemplateAndUniqueID.new('important-field' => '2').save
      WithTemplateAndUniqueID.new('important-field' => '3').save
      WithTemplateAndUniqueID.new('important-field' => '4').save
    end
    it "should make the design doc" do
      WithTemplateAndUniqueID.all
      d = WithTemplateAndUniqueID.design_doc
      d['views']['all']['map'].should include('WithTemplateAndUniqueID')
    end
    it "should find first" do
      rs = WithTemplateAndUniqueID.first
      rs['important-field'].should == "1"
    end
    it "should return nil if no instances are found" do
      WithTemplateAndUniqueID.all.each {|obj| obj.destroy }
      WithTemplateAndUniqueID.first.should be_nil
    end
  end

  describe "getting a model with a subobject field" do
    before(:all) do
      course_doc = {
        "title" => "Metaphysics 410",
        "professor" => {
          "name" => ["Mark", "Hinchliff"]
        },
        "final_test_at" => "2008/12/19 13:00:00 +0800"
      }
      r = Course.database.save_doc course_doc
      @course = Course.get r['id']
    end
    it "should load the course" do
      @course["professor"]["name"][1].should == "Hinchliff"
    end
    it "should instantiate the professor as a person" do
      @course['professor'].last_name.should == "Hinchliff"
    end
    it "should instantiate the final_test_at as a Time" do
      @course['final_test_at'].should == Time.parse("2008/12/19 13:00:00 +0800")
    end
  end

  describe "cast keys to any type" do
    before(:all) do
      @event = Event.create(:subject => "Some event", :occurs_at => Time.now)
    end
    it "should cast created_at to Time" do
      @event.occurs_at.should be_an_instance_of(Time)
    end

    it "should cast created_at to Time after instantiating" do
      @event = Event.get(@event.id)
      @event.occurs_at.should be_an_instance_of(Time)
    end
  end

  describe "saving a model" do
    before(:all) do
      @obj = Basic.new(:foo => "Bar")
      @obj.save.should == true
    end

    it "should save the doc" do
      doc = @obj.database.get @obj.id
      doc['_id'].should == @obj.id
    end

    it "should be set for resaving" do
      rev = @obj.rev
      @obj['another-key'] = "some value"
      @obj.save
      @obj.rev.should_not == rev
    end

    it "should set the id" do
      @obj.id.should be_an_instance_of(String)
    end

    it "should set the type" do
      @obj['couchrest-type'].should == 'Basic'
    end
  end

  describe "creating an instance" do
    before(:all) do
      @obj = Basic.create(:foo => "Bar")
    end

    it "should save the doc" do
      doc = @obj.database.get @obj.id
      doc['_id'].should == @obj.id
    end

    it "should be set for resaving" do
      rev = @obj.rev
      @obj['another-key'] = "some value"
      @obj.save
      @obj.rev.should_not == rev
    end

    it "should set the id" do
      @obj.id.should be_an_instance_of(String)
    end

    it "should set the type" do
      @obj['couchrest-type'].should == 'Basic'
    end

    it "should be the same as the retrieved instance" do
      @obj = Basic.create(:foo => "Bar")
      @obj.should == Basic.get(@obj.id)
    end
  end

  describe "saving a model with validation hooks added as extlib" do
    before(:all) do
      @obj = BasicWithValidation.new
    end

    it "save should return false is the model doesn't save as expected" do
      @obj.save.should be_false
    end

    it "save! should raise and exception if the model doesn't save" do
      lambda{ @obj.save!}.should raise_error("#{@obj.inspect} failed to save")
    end
  end

  describe "updating a model with a hook added as extlib" do

    it "should run the hook method" do
      @obj = BasicWithValidation.new(:name => "Foo")
      @obj.save.should be_true
      @obj.save
      @obj.name.should == "Bar"
    end

  end

  describe "saving a model with a unique_id configured" do
    before(:each) do
      @art = Article.new
      @old = Article.database.get('this-is-the-title') rescue nil
      Article.database.delete_doc(@old) if @old
    end

    it "should be a new document" do
      @art.should be_a_new_document
      @art.title.should be_nil
    end

    it "should require the title" do
      lambda{@art.save}.should raise_error
      @art.title = 'This is the title'
      @art.save.should == true
    end

    it "should not change the slug on update" do
      @art.title = 'This is the title'
      @art.save.should == true
      @art.title = 'new title'
      @art.save.should == true
      @art.slug.should == 'this-is-the-title'
    end

    it "should raise an error when the slug is taken" do
      @art.title = 'This is the title'
      @art.save.should == true
      @art2 = Article.new(:title => 'This is the title!')
      lambda{@art2.save}.should raise_error
    end

    it "should set the slug" do
      @art.title = 'This is the title'
      @art.save.should == true
      @art.slug.should == 'this-is-the-title'
    end

    it "should set the id" do
      @art.title = 'This is the title'
      @art.save.should == true
      @art.id.should == 'this-is-the-title'
    end
  end

  describe "saving a model with a unique_id lambda" do
    before(:each) do
      @templated = WithTemplateAndUniqueID.new
      @old = WithTemplateAndUniqueID.get('very-important') rescue nil
      @old.destroy if @old
    end

    it "should require the field" do
      lambda{@templated.save}.should raise_error
      @templated['important-field'] = 'very-important'
      @templated.save.should == true
    end

    it "should save with the id" do
      @templated['important-field'] = 'very-important'
      @templated.save.should == true
      t = WithTemplateAndUniqueID.get('very-important')
      t.should == @templated
    end

    it "should not change the id on update" do
      @templated['important-field'] = 'very-important'
      @templated.save.should == true
      @templated['important-field'] = 'not-important'
      @templated.save.should == true
      t = WithTemplateAndUniqueID.get('very-important')
      t.should == @templated
    end

    it "should raise an error when the id is taken" do
      @templated['important-field'] = 'very-important'
      @templated.save.should == true
      lambda{WithTemplateAndUniqueID.new('important-field' => 'very-important').save}.should raise_error
    end

    it "should set the id" do
      @templated['important-field'] = 'very-important'
      @templated.save.should == true
      @templated.id.should == 'very-important'
    end
  end

  describe "a model with timestamps" do
    before(:each) do
      oldart = Article.get "saving-this" rescue nil
      oldart.destroy if oldart
      @art = Article.new(:title => "Saving this")
      @art.save
    end
    it "should set the time on create" do
      (Time.now - @art.created_at).should < 2
      foundart = Article.get @art.id
      foundart.created_at.should == foundart.updated_at
    end
    it "should set the time on update" do
      sleep 1 # HACK!! Sometimes takes less than a second to call save the second time. Really should mock this!
      @art.save
      @art.created_at.should < @art.updated_at
    end

    it "should return both created_at and updated_at as instances of Time" do
      @art.created_at.should be_kind_of(Time)
      @art.updated_at.should be_kind_of(Time)
    end
    it "when retrieved should return both created_at and updated_at as instances of Time" do
      foundart = Article.get @art.id
      foundart.created_at.should be_kind_of(Time)
      foundart.updated_at.should be_kind_of(Time)
    end
  end

  describe "a model with simple views, a list and a default param" do
    before(:all) do
      written_at = Time.now - 24 * 3600 * 7
      @titles = ["this and that", "also interesting", "more fun", "some junk"]
      @titles.each do |title|
        a = Article.new(:title => title)
        a.date = written_at
        a.save
        written_at += 24 * 3600
      end
    end

    it "should have a design doc" do
      Article.design_doc["views"]["by_date"].should_not be_nil
    end

    it "should save the design doc" do
      Article.by_date #rescue nil
      doc = Article.database.get Article.design_doc.id
      doc['views']['by_date'].should_not be_nil
    end

    it "should return the matching raw view result" do
      view = Article.by_date :raw => true
      view['rows'].length.should == 4
    end

    it "should not include non-Articles" do
      Article.database.save_doc({"date" => 1})
      view = Article.by_date :raw => true
      view['rows'].length.should == 4
    end

    it "should return the matching objects (with default argument :descending => true)" do
      articles = Article.by_date
      articles.collect{|a|a.title}.should == @titles.reverse
    end

    it "should allow you to override default args" do
      articles = Article.by_date :descending => false
      articles.collect{|a|a.title}.should == @titles
    end

    it "should return the results of the list" do
      Article.list(:names, :using => :by_date, :options => {:include_docs => true}).should == "this and thatalso interestingmore funsome junk"
    end
  end

  describe "another model with a simple view" do
    before(:all) do
      Course.database.delete! rescue nil
      @db = @cr.create_db(TESTDB) rescue nil
      %w{aaa bbb ddd eee}.each do |title|
        Course.new(:title => title).save
      end
    end
    it "should make the design doc upon first query" do
      Course.by_title
      doc = Course.design_doc
      doc['views']['all']['map'].should include('Course')
    end
    it "should can query via view" do
      # register methods with method-missing, for local dispatch. method
      # missing lookup table, no heuristics.
      view = Course.view :by_title
      designed = Course.by_title
      view.should == designed
    end
    it "should get them" do
      rs = Course.by_title
      rs.length.should == 4
    end
    it "should yield" do
      courses = []
      rs = Course.by_title # remove me
      Course.view(:by_title) do |course|
        courses << course
      end
      courses[0]["doc"]["title"].should =='aaa'
    end
  end

  describe "a ducktype view" do
    before(:all) do
      @id = @db.save_doc({:dept => true})['id']
    end
    it "should setup" do
      duck = Course.get(@id) # from a different db
      duck["dept"].should == true
    end
    it "should make the design doc" do
      @as = Course.by_dept
      @doc = Course.design_doc
      @doc["views"]["by_dept"]["map"].should_not include("couchrest")
    end
    it "should not look for class" do |variable|
      @as = Course.by_dept
      @as[0]['_id'].should == @id
    end
  end

  describe "a model with a compound key view" do
    before(:all) do
      written_at = Time.now - 24 * 3600 * 7
      @titles = ["uniq one", "even more interesting", "less fun", "not junk"]
      @user_ids = ["quentin", "aaron"]
      @titles.each_with_index do |title,i|
        u = i % 2
        a = Article.new(:title => title, :user_id => @user_ids[u])
        a.date = written_at
        a.save
        written_at += 24 * 3600
      end
    end
    it "should create the design doc" do
      Article.by_user_id_and_date rescue nil
      doc = Article.design_doc
      doc['views']['by_date'].should_not be_nil
    end
    it "should sort correctly" do
      articles = Article.by_user_id_and_date
      articles.collect{|a|a['user_id']}.should == ['aaron', 'aaron', 'quentin',
        'quentin']
      articles[1].title.should == 'not junk'
    end
    it "should be queryable with couchrest options" do
      articles = Article.by_user_id_and_date :limit => 1, :startkey => 'quentin'
      articles.length.should == 1
      articles[0].title.should == "even more interesting"
    end
  end

  describe "with a custom view" do
    before(:all) do
      @titles = ["very uniq one", "even less interesting", "some fun",
        "really junk", "crazy bob"]
      @tags = ["cool", "lame"]
      @titles.each_with_index do |title,i|
        u = i % 2
        a = Article.new(:title => title, :tags => [@tags[u]])
        a.save
      end
    end
    it "should be available raw" do
      view = Article.by_tags :raw => true
      view['rows'].length.should == 5
    end

    it "should be default to :reduce => false" do
      ars = Article.by_tags
      ars.first.tags.first.should == 'cool'
    end

    it "should be raw when reduce is true" do
      view = Article.by_tags :reduce => true, :group => true
      view['rows'].find{|r|r['key'] == 'cool'}['value'].should == 3
    end
  end

  # TODO: moved to Design, delete
  describe "adding a view" do
    before(:each) do
      Article.by_date
      @design_docs = Article.database.documents :startkey => "_design/",
        :endkey => "_design/\u9999"
    end
    it "should not create a design doc on view definition" do
      Article.view_by :created_at
      newdocs = Article.database.documents :startkey => "_design/",
        :endkey => "_design/\u9999"
      newdocs["rows"].length.should == @design_docs["rows"].length
    end
    it "should create a new design document on view access" do
      Article.view_by :updated_at
      Article.by_updated_at
      newdocs = Article.database.documents :startkey => "_design/",
        :endkey => "_design/\u9999"
      newdocs["rows"].length.should == @design_docs["rows"].length + 1
    end
  end

  describe "with a lot of designs left around" do
    before(:each) do
      Article.by_date
      Article.view_by :field
      Article.by_field
    end
    it "should clean them up" do
      Article.view_by :stream
      Article.by_stream
      ddocs = Article.all_design_doc_versions
      ddocs["rows"].length.should > 1
      Article.cleanup_design_docs!
      ddocs = Article.all_design_doc_versions
      ddocs["rows"].length.should == 1
    end
  end

  describe "destroying an instance" do
    before(:each) do
      @obj = Basic.new
      @obj.save.should == true
    end
    it "should return true" do
      result = @obj.destroy
      result.should == true
    end
    it "should be resavable" do
      @obj.destroy
      @obj.rev.should be_nil
      @obj.id.should be_nil
      @obj.save.should == true
    end
    it "should make it go away" do
      @obj.destroy
      lambda{Basic.get(@obj.id)}.should raise_error
    end
  end

  describe "#has_attachment?" do
    before(:each) do
      @obj = Basic.new
      @obj.save.should == true
      @file = File.open(FIXTURE_PATH + '/attachments/test.html')
      @attachment_name = 'my_attachment'
      @obj.create_attachment(:file => @file, :name => @attachment_name)
    end

    it 'should return false if there is no attachment' do
      @obj.has_attachment?('bogus').should be_false
    end

    it 'should return true if there is an attachment' do
      @obj.has_attachment?(@attachment_name).should be_true
    end

    it 'should return true if an object with an attachment is reloaded' do
      @obj.save.should be_true
      reloaded_obj = Basic.get(@obj.id)
      reloaded_obj.has_attachment?(@attachment_name).should be_true
    end

    it 'should return false if an attachment has been removed' do
      @obj.delete_attachment(@attachment_name)
      @obj.has_attachment?(@attachment_name).should be_false
    end
  end

  describe "creating an attachment" do
    before(:each) do
      @obj = Basic.new
      @obj.save.should == true
      @file_ext = File.open(FIXTURE_PATH + '/attachments/test.html')
      @file_no_ext = File.open(FIXTURE_PATH + '/attachments/README')
      @attachment_name = 'my_attachment'
      @content_type = 'media/mp3'
    end

    it "should create an attachment from file with an extension" do
      @obj.create_attachment(:file => @file_ext, :name => @attachment_name)
      @obj.save.should == true
      reloaded_obj = Basic.get(@obj.id)
      reloaded_obj['_attachments'][@attachment_name].should_not be_nil
    end

    it "should create an attachment from file without an extension" do
      @obj.create_attachment(:file => @file_no_ext, :name => @attachment_name)
      @obj.save.should == true
      reloaded_obj = Basic.get(@obj.id)
      reloaded_obj['_attachments'][@attachment_name].should_not be_nil
    end

    it 'should raise ArgumentError if :file is missing' do
      lambda{ @obj.create_attachment(:name => @attachment_name) }.should raise_error
    end

    it 'should raise ArgumentError if :name is missing' do
      lambda{ @obj.create_attachment(:file => @file_ext) }.should raise_error
    end

    it 'should set the content-type if passed' do
      @obj.create_attachment(:file => @file_ext, :name => @attachment_name, :content_type => @content_type)
      @obj['_attachments'][@attachment_name]['content-type'].should == @content_type
    end
  end

  describe 'reading, updating, and deleting an attachment' do
    before(:each) do
      @obj = Basic.new
      @file = File.open(FIXTURE_PATH + '/attachments/test.html')
      @attachment_name = 'my_attachment'
      @obj.create_attachment(:file => @file, :name => @attachment_name)
      @obj.save.should == true
      @file.rewind
      @content_type = 'media/mp3'
    end

    it 'should read an attachment that exists' do
      @obj.read_attachment(@attachment_name).should == @file.read
    end

    it 'should update an attachment that exists' do
      file = File.open(FIXTURE_PATH + '/attachments/README')
      @file.should_not == file
      @obj.update_attachment(:file => file, :name => @attachment_name)
      @obj.save
      reloaded_obj = Basic.get(@obj.id)
      file.rewind
      reloaded_obj.read_attachment(@attachment_name).should_not == @file.read
      reloaded_obj.read_attachment(@attachment_name).should == file.read
    end

    it 'should se the content-type if passed' do
      file = File.open(FIXTURE_PATH + '/attachments/README')
      @file.should_not == file
      @obj.update_attachment(:file => file, :name => @attachment_name, :content_type => @content_type)
      @obj['_attachments'][@attachment_name]['content-type'].should == @content_type
    end

    it 'should delete an attachment that exists' do
      @obj.delete_attachment(@attachment_name)
      @obj.save
      lambda{Basic.get(@obj.id).read_attachment(@attachment_name)}.should raise_error
    end
  end

  describe "#attachment_url" do
    before(:each) do
      @obj = Basic.new
      @file = File.open(FIXTURE_PATH + '/attachments/test.html')
      @attachment_name = 'my_attachment'
      @obj.create_attachment(:file => @file, :name => @attachment_name)
      @obj.save.should == true
    end

    it 'should return nil if attachment does not exist' do
      @obj.attachment_url('bogus').should be_nil
    end

    it 'should return the attachment URL as specified by CouchDB HttpDocumentApi' do
      @obj.attachment_url(@attachment_name).should == "#{Basic.database}/#{@obj.id}/#{@attachment_name}"
    end
  end

  describe "#to_json" do
    it "should return the a JSON representation of the attributes hash" do
      article = Article.new(:title => "My Article")
      article.to_json.should == "{\"title\":\"My Article\",\"couchrest-type\":\"Article\"}"
    end
  end

  describe "#reload!" do
    it "should re-intialise the object from the database" do
      @obj = Basic.new
      @file = File.open(FIXTURE_PATH + '/attachments/test.html')
      @attachment_name = 'my_attachment'
      @obj.create_attachment(:file => @file, :name => @attachment_name)
      @obj.save.should == true
      @obj["_attachments"]["my_attachment"].should_not have_key("length")
      @obj.reload["_attachments"]["my_attachment"].should have_key("length")
    end
  end
end
