require 'typhoeus'
class Hash
  def kick
    self
  end
end
module CouchSurfer
  class Database

    class AlreadyExists < StandardError;end
    class NotFound < StandardError;end
    class NonJsonDocument < StandardError;end

    include Typhoeus

    define_remote_method  :create, :path => '/:name', :method => :put, :base_uri => Configuration.host,
                          :on_success =>  lambda {|response| p response.body;JSON.parse(response.body)},
                          :on_failure =>  lambda {raise AlreadyExists}

    define_remote_method  :destroy, :path => '/:name', :method => :delete, :base_uri => Configuration.host,
                          :on_success =>  lambda {|response| JSON.parse(response.body)},
                          :on_failure =>  lambda {raise NotFound}

    define_remote_method  :list, :path => '/_all_dbs', :method => :get, :base_uri => Configuration.host,
                          :on_success =>  lambda {|response| JSON.parse(response.body)}

    define_remote_method  :use, :path => '/:name', :method => :get, :base_uri => Configuration.host,
                          :on_success =>  lambda {|response| Database.new(JSON.parse(response.body))},
                          :on_failure =>  lambda {raise NotFound}

    define_remote_method  :save_doc, :path => '/:name/:slug', :method => :put, :base_uri => Configuration.host,
                          :on_success =>  lambda {|response| JSON.parse(response.body)},
                          :on_failure =>  lambda {raise NonJsonDocument}

    def self.destroy!(options)
      destroy(options).kick
    end

    def self.create!(options)
      create(options).kick
    end

    def self.use!(options)
      use(options).kick
    end

    attr_reader :purge_seq, :doc_count, :instance_start_time, :update_seq, :disk_size, :compact_running, :db_name, :doc_del_count

    def initialize(options)
      @purge_seq = options['purge_seq']
      @doc_count = options['doc_count']
      @instance_start_time = options['instance_start_time']
      @update_seq = options['update_seq']
      @disk_size = options['disk_size']
      @compact_running = options['compact_running']
      @db_name = options['db_name']
      @doc_del_count = options['doc_del_count']
    end

    def save_doc(document_hash)
      Database.save_doc(:name => db_name, :slug => "FOO", :body => document_hash.to_json)
    end
  end
end