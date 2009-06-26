require File.dirname(__FILE__) + '/../spec_helper.rb'

module CouchSurfer

  describe Configuration do
    it "should have a setter/getter for the host" do
      Configuration.host = "http://localhost:5984"
      Configuration.host.should == "http://localhost:5984"
    end
  end
end