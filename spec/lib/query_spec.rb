require File.dirname(__FILE__) + '/../spec_helper.rb'

class Person
  include CouchSurfer::Model
  include CouchSurfer::Query

  query_processor :query_person

  key_accessor :name, :email

  view_by :name
end

describe CouchSurfer::Query do
  before(:all) do
    db = CouchRest.database!('couch_surfer-test')
    db.delete!
    CouchSurfer::Model.default_database = CouchRest.database!('http://127.0.0.1:5984/couch_surfer-test')
  end
  
  before do
    CouchRest.stub!(:post).and_return({"rows"=>[{"doc"=>{"name"=>"John", "email" => "john@mail.com"}}, {"doc"=>{"name"=>"Johnson", "email" => "johnson@mail.com"}}]})
  end

  it "should pass on the query to the '_mix' handler, and include the docs by default" do
    payload = {:design => "Person-f048e6d2ad225649c5eaa30511a1a310", :view => {:name => :by_name, :query => {:include_docs => true}}, :external =>  {:name =>  :query_person, :query =>  {:q =>  "John"}, :include_docs =>  true}}
    CouchRest.should_receive(:post).with("http://#{Person.database}/_mix", payload.to_json).and_return({"rows"=>[{"doc"=>{"name"=>"John", "email" => "john@mail.com"}}, {"doc"=>{"name"=>"Johnson", "email" => "johnson@mail.com"}}]})
    people = Person.query(:by_name, "John")
    people.size.should == 2
    people.map{|p| p.name}.sort.should == ["John", "Johnson"]
  end
  
  it "should serialise the results as instances of the calling model" do
    people = Person.query(:by_name, "John")
    people.each{|person| person.should be_instance_of(Person)}
  end
  
  it "should pass on all options to the '_mix' handler, stringifying the values" do
    payload = {
      :design => "Person-f048e6d2ad225649c5eaa30511a1a310", 
      :view => {:name => :by_name, :query => {
        :limit => 5, 
        :startkey => ["AAA", "SDFG"], 
        :endkey => "QQQ", 
        :descending => true, 
        :include_docs => true}
      }, 
      :external =>  {:name =>  :query_person, :query =>  {
        :q =>  "John"
        },
        :include_docs =>  true
      }
    }
    CouchRest.should_receive(:post).with("http://#{Person.database}/_mix", payload.to_json).and_return({"rows"=>[{"doc"=>{"name"=>"John", "email" => "john@mail.com"}}, {"doc"=>{"name"=>"Johnson", "email" => "johnson@mail.com"}}]})
    people = Person.query(:by_name, "John", {:limit => 5, :startkey => ["AAA", "SDFG"], :endkey => "QQQ", :descending => true})
  end
end
