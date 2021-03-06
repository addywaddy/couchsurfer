require 'digest/md5'
require 'mime/types'

module CouchSurfer

  class RecordNotFound < RestClient::ResourceNotFound; end

  module Model
    @database = nil
    def self.default_database
      @database
    end

    def self.default_database= db
      @database = db
    end

    # Adapted from ActiveSupport Time#formatted_offset
    def self.format_utc_offset(time)
      seconds_offset_from_utc = time.utc_offset
      sign = (seconds_offset_from_utc < 0 ? -1 : 1)
      hours = seconds_offset_from_utc.abs / 3600
      minutes = (seconds_offset_from_utc.abs % 3600) / 60
      "%+03d%02d" % [ hours * sign, minutes ]
    end

    module ClassMethods
      # override the CouchSurfer::Model-wide default_database
      def use_database db
        self.class_database = db
      end

      # returns the CouchRest::Database instance that this class uses
      def database
        self.class_database || CouchSurfer::Model.default_database
      end

      # Load a document from the database by id
      def get id
        doc = database.get id
        new(doc)
      rescue
        RestClient::ResourceNotFound
        raise CouchSurfer::RecordNotFound
      end

      def create(attrs = {})
        instance = new(attrs)
        instance.save
        instance
      end

      # Load all documents that have the "couchrest-type" field equal to the
      # name of the current class. Take the standard set of
      # CouchRest::Database#view options.
      def all opts = {}, &block
        self.design_doc ||= CouchRest::Design.new(default_design_doc)
        unless design_doc_fresh
          refresh_design_doc
        end
        view :all, opts, &block
      end

      # Load the first document that have the "couchrest-type" field equal to
      # the name of the current class.
      #
      # ==== Returns
      # Object:: The first object instance available
      # or
      # Nil:: if no instances available
      #
      # ==== Parameters
      # opts<Hash>::
      # View options, see <tt>CouchRest::Database#view</tt> options for more info.
      def first opts = {}
        first_instance = self.all(opts.merge!(:limit => 1))
        first_instance.empty? ? nil : first_instance.first
      end

      # Cast a field as another class. The class must be happy to have the
      # field's primitive type as the argument to it's constuctur. Classes
      # which inherit from CouchRest::Model are happy to act as sub-objects
      # for any fields that are stored in JSON as object (and therefore are
      # parsed from the JSON as Ruby Hashes).
      #
      # Example:
      #
      #   class Post < CouchRest::Model
      #
      #     key_accessor :title, :body, :author
      #
      #     cast :author, :as => 'Author'
      #
      #   end
      #
      #   post.author.class #=> Author
      #
      # Using the same example, if a Post should have many Comments, we
      # would declare it like this:
      #
      #   class Post < CouchRest::Model
      #
      #     key_accessor :title, :body, :author, comments
      #
      #     cast :author, :as => 'Author'
      #     cast :comments, :as => ['Comment']
      #
      #   end
      #
      #   post.author.class #=> Author
      #   post.comments.class #=> Array
      #   post.comments.first #=> Comment
      #
      def cast field, opts = {}
        self.casts ||= {}
        self.casts[field.to_s] = opts
      end

      # Defines methods for reading and writing from fields in the document.
      # Uses key_writer and key_reader internally.
      def key_accessor *keys
        key_writer *keys
        key_reader *keys
      end

      # For each argument key, define a method <tt>key=</tt> that sets the
      # corresponding field on the CouchDB document.
      def key_writer *keys
        keys.each do |method|
          key = method.to_s
          define_method "#{method}=" do |value|
            @attributes[method] = value# ||= nil
          end
        end
      end

      # For each argument key, define a method <tt>key</tt> that reads the
      # corresponding field on the CouchDB document.
      def key_reader *keys
        keys.each do |method|
          key = method.to_s
          define_method method do
            @attributes[method]
          end
        end
      end

      def set_default hash
        self.default_obj = hash
      end

      def default
        self.default_obj
      end

      # Automatically set <tt>updated_at</tt> and <tt>created_at</tt> fields
      # on the document whenever saving occurs. Save in a format parseable by Time
      # and including milliseconds

      def timestamps!
        %w(updated_at created_at).each do |method|
          define_method method do
            Time.parse(@attributes[method])
          end
        end
        before(:save) do
          time = Time.now
          utc_offset = CouchSurfer::Model.format_utc_offset(time)
          self['updated_at'] = time.strftime("%Y/%m/%d %H:%M:%S.#{time.usec} #{utc_offset}")
          self['created_at'] = self['updated_at'] if new_document?
        end
      end

      # Name a method that will be called before the document is first saved,
      # which returns a string to be used for the document's <tt>_id</tt>.
      # Because CouchDB enforces a constraint that each id must be unique,
      # this can be used to enforce eg: uniq usernames. Note that this id
      # must be globally unique across all document types which share a
      # database, so if you'd like to scope uniqueness to this class, you
      # should use the class name as part of the unique id.
      def unique_id method = nil, &block
        if method
          define_method :set_unique_id do
            self['_id'] ||= self.send(method)
          end
        elsif block
          define_method :set_unique_id do
            uniqid = block.call(self)
            raise ArgumentError, "unique_id block must not return nil" if uniqid.nil?
            self['_id'] ||= uniqid
          end
        end
      end

      # Define a CouchDB view. The name of the view will be the concatenation
      # of <tt>by</tt> and the keys joined by <tt>_and_</tt>
      #
      # ==== Example views:
      #
      #   class Post
      #     # view with default options
      #     # query with Post.by_date
      #     view_by :date, :descending => true
      #
      #     # view with compound sort-keys
      #     # query with Post.by_user_id_and_date
      #     view_by :user_id, :date
      #
      #     # view with custom map/reduce functions
      #     # query with Post.by_tags :reduce => true
      #     view_by :tags,
      #       :map =>
      #         "function(doc) {
      #           if (doc['couchrest-type'] == 'Post' && doc.tags) {
      #             doc.tags.forEach(function(tag){
      #               emit(doc.tag, 1);
      #             });
      #           }
      #         }",
      #       :reduce =>
      #         "function(keys, values, rereduce) {
      #           return sum(values);
      #         }"
      #   end
      #
      # <tt>view_by :date</tt> will create a view defined by this Javascript
      # function:
      #
      #   function(doc) {
      #     if (doc['couchrest-type'] == 'Post' && doc.date) {
      #       emit(doc.date, null);
      #     }
      #   }
      #
      # It can be queried by calling <tt>Post.by_date</tt> which accepts all
      # valid options for CouchRest::Database#view. In addition, calling with
      # the <tt>:raw => true</tt> option will return the view rows
      # themselves. By default <tt>Post.by_date</tt> will return the
      # documents included in the generated view.
      #
      # CouchRest::Database#view options can be applied at view definition
      # time as defaults, and they will be curried and used at view query
      # time. Or they can be overridden at query time.
      #
      # Custom views can be queried with <tt>:reduce => true</tt> to return
      # reduce results. The default for custom views is to query with
      # <tt>:reduce => false</tt>.
      #
      # Views are generated (on a per-model basis) lazily on first-access.
      # This means that if you are deploying changes to a view, the views for
      # that model won't be available until generation is complete. This can
      # take some time with large databases. Strategies are in the works.
      #
      # To understand the capabilities of this view system more compeletly,
      # it is recommended that you read the RSpec file at
      # <tt>spec/core/model_spec.rb</tt>.
      def view_by *keys
        self.design_doc ||= CouchRest::Design.new(default_design_doc)
        opts = keys.pop if keys.last.is_a?(Hash)
        opts ||= {}
        ducktype = opts.delete(:ducktype)
        unless ducktype || opts[:map]
          opts[:guards] ||= []
          opts[:guards].push "(doc['couchrest-type'] == '#{self.to_s}')"
        end
        keys.push opts
        self.design_doc.view_by(*keys)
        self.design_doc_fresh = false
      end

      def method_missing m, *args
        if has_view?(m)
          query = args.shift || {}
          view(m, query, *args)
        else
          CouchRest::Document.send(:method_missing, m, *args)
        end
      end

      # returns stored defaults if the there is a view named this in the design doc
      def has_view?(view)
        view = view.to_s
        design_doc && design_doc['views'] && design_doc['views'][view]
      end

      # Dispatches to any named view.
      def view name, query={}, &block
        unless design_doc_fresh
          refresh_design_doc
        end
        query[:raw] = true if query[:reduce]
        raw = query.delete(:raw)
        fetch_view_with_docs(name, query, raw, &block)
      end

      def all_design_doc_versions
        database.documents :startkey => "_design/#{self.to_s}-",
          :endkey => "_design/#{self.to_s}-\u9999"
      end

      # Deletes any non-current design docs that were created by this class.
      # Running this when you're deployed version of your application is steadily
      # and consistently using the latest code, is the way to clear out old design
      # docs. Running it too early could mean that live code has to regenerate
      # potentially large indexes.
      def cleanup_design_docs!
        ddocs = all_design_doc_versions
        ddocs["rows"].each do |row|
          if (row['id'] != design_doc_id)
            database.delete_doc({
              "_id" => row['id'],
              "_rev" => row['value']['rev']
            })
          end
        end
      end

      def lists(lists_hash)
        design_doc['lists'] = lists_hash
      end

      def list(*args)
        unless design_doc_fresh
          refresh_design_doc
        end
        list_name = args.first
        view_name = args.last[:using]
        options = args.last[:options]
        response = design_doc.list(list_name, view_name, options)
        if response['rows']
          response['rows'].collect{|r|new(r['doc'])}
        else
          response
        end
      end

      private

      def fetch_view_with_docs name, opts, raw=false, &block
        if raw
          fetch_view name, opts, &block
        else
          begin
            view = fetch_view name, opts.merge({:include_docs => true}), &block
            view['rows'].collect{|r|new(r['doc'])} if view['rows']
          rescue
            # fallback for old versions of couchdb that don't
            # have include_docs support
            view = fetch_view name, opts, &block
            view['rows'].collect{|r|new(database.get(r['id']))} if view['rows']
          end
        end
      end

      def fetch_view view_name, opts, &block
        retryable = true
        begin
          design_doc.view(view_name, opts, &block)
          # the design doc could have been deleted by a rouge process
        rescue RestClient::ResourceNotFound => e
          if retryable
            refresh_design_doc
            retryable = false
            retry
          else
            raise e
          end
        end
      end

      def design_doc_id
        "_design/#{design_doc_slug}"
      end

      def design_doc_slug
        return design_doc_slug_cache if design_doc_slug_cache && design_doc_fresh
        funcs = []
        design_doc['views'].each do |name, view|
          funcs << "#{name}/#{view['map']}#{view['reduce']}"
        end
        funcs << design_doc['lists'].map {|name, func| func }# if design_doc['lists']
        funcs.flatten!
        md5 = Digest::MD5.hexdigest(funcs.sort.join(''))
        self.design_doc_slug_cache = "#{self.to_s}-#{md5}"
      end

      def default_design_doc
        {
          "language" => "javascript",
          "lists" => {},
          "shows" => {},
          "views" => {
            'all' => {
              'map' => "function(doc) {
                if (doc['couchrest-type'] == '#{self.to_s}') {
                  emit(doc['_id'],null);
                }
              }"
            }
          }
        }
      end

      def refresh_design_doc
        did = design_doc_id
        saved = database.get(did) rescue nil
        if saved
          design_doc['views'].each do |name, view|
            saved['views'][name] = view
          end
          design_doc['lists'].each do |name, view|
            saved['lists'][name] = view
          end
          design_doc['shows'].each do |name, view|
            saved['shows'][name] = view
          end
          database.save_doc(saved)
          design_doc['_id'] = did
          design_doc.database = database
        else
          design_doc['_id'] = did
          design_doc.delete('_rev')
          design_doc.database = database
          design_doc.save
        end
        self.design_doc_fresh = true
      end

    end

    module InstanceMethods

      # Rails-specific
      def to_param
        id
      end

      # Rails-specific
      def new_record?
        id.nil?
      end

      # returns the database used by this model's class
      def database
        self.class.database
      end

      # Takes a hash as argument, and applies the values by using writer methods
      # for each key. It doesn't save the document at the end. Raises a NoMethodError if the corresponding methods are
      # missing. In case of error, no attributes are changed.
      def update_attributes_without_saving hash
        hash.each do |k, v|
          raise NoMethodError, "#{k}= method not available, use key_accessor or key_writer :#{k}" unless self.respond_to?("#{k}=")
        end
        hash.each do |k, v|
          @attributes[k] = v
        end
      end

      # Takes a hash as argument, and applies the values by using writer methods
      # for each key. Raises a NoMethodError if the corresponding methods are
      # missing. In case of error, no attributes are changed.
      def update_attributes hash
        update_attributes_without_saving hash
        save
      end

      def []= key, value
        @attributes[key.to_s] = value
      end

      def [] key
        @attributes[key.to_s]
      end

      def key? key
        @attributes.key? key
      end

      def new_document?
        !@attributes['_rev']
      end

      def id
        @attributes.id
      end

      def identity_field
        [CouchSurfer::Model, :id]
      end

      def rev
        @attributes.rev
      end

      # Is this OK?
      def == other_object
        attributes == other_object.attributes
      end

      def reload
        reloaded_doc = self.class.get(id)
        @attributes = reloaded_doc.attributes
        self
      end
      # def save
      #   @attributes.database = self.class.database
      #   @attributes.save
      # end

      # Overridden to set the unique ID.
      def save bulk = false
        if new_document?
          create(bulk)
        else
          update(bulk)
        end
      end

      # Saves the document to the db using create or update. Raises an exception
      # if the document is not saved properly.
      def save!
        raise "#{self.inspect} failed to save" unless self.save
      end

      # Deletes the document from the database. Runs the :destroy callbacks.
      # Removes the <tt>_id</tt> and <tt>_rev</tt> fields, preparing the
      # document to be saved to a new <tt>_id</tt>.
      def destroy
        result = database.delete_doc self
        if result['ok']
          self['_rev'] = nil
          self['_id'] = nil
        end
        result['ok']
      end

      # creates a file attachment to the current doc
      def create_attachment(args={})
        raise ArgumentError unless args[:file] && args[:name]
        return if has_attachment?(args[:name])
        self['_attachments'] ||= {}
        set_attachment_attr(args)
      rescue ArgumentError => e
        raise ArgumentError, 'You must specify :file and :name'
      end

      # reads the data from an attachment
      def read_attachment(attachment_name)
        Base64.decode64(database.fetch_attachment(self, attachment_name))
      end

      # modifies a file attachment on the current doc
      def update_attachment(args={})
        raise ArgumentError unless args[:file] && args[:name]
        return unless has_attachment?(args[:name])
        delete_attachment(args[:name])
        set_attachment_attr(args)
      rescue ArgumentError => e
        raise ArgumentError, 'You must specify :file and :name'
      end

      # deletes a file attachment from the current doc
      def delete_attachment(attachment_name)
        return unless self['_attachments']
        self['_attachments'].delete attachment_name
      end

      # returns true if attachment_name exists
      def has_attachment?(attachment_name)
        !!(self['_attachments'] && self['_attachments'][attachment_name] && !self['_attachments'][attachment_name].empty?)
      end

      # returns URL to fetch the attachment from
      def attachment_url(attachment_name)
        return unless has_attachment?(attachment_name)
        "#{database.root}/#{self.id}/#{attachment_name}"
      end

      def to_json
        attributes.to_json
      end

      protected

      def create bulk = false
        set_unique_id if self.respond_to?(:set_unique_id)
        save_doc(bulk)
      end

      def update bulk = false
        save_doc(bulk)
      end

      def save_doc bulk = false
        @attributes.database = self.class.database
        @attributes.delete('_rev') unless @attributes['_rev']
        @attributes.save(bulk)
      end

      private

      def apply_defaults
        return unless new_document?
        if self.class.default
          self.class.default.each do |k,v|
            unless self.key?(k.to_s)
              if v.class == Proc
                self[k.to_s] = v.call
              else
                self[k.to_s] = Marshal.load(Marshal.dump(v))
              end
            end
          end
        end
      end

      def cast_keys
        return unless self.class.casts
        # TODO move the argument checking to the cast method for early crashes
        self.class.casts.each do |k,v|
          next unless self[k]
          target = v[:as]
          v[:send] || 'new'
          if target.is_a?(Array)
            klass = ::Extlib::Inflection.constantize(target[0])
            self[k] = self[k].collect do |value|
              (!v[:send] && klass == Time) ? Time.parse(value) : klass.send((v[:send] || 'new'), value)
            end
          else
            self[k] = if (!v[:send] && target == 'Time')
              self[k].is_a?(Time) ? self[k] : Time.parse(self[k])
            else
              ::Extlib::Inflection.constantize(target).send((v[:send] || 'new'), self[k])
            end
          end
        end
      end

      def encode_attachment(data)
        Base64.encode64(data).gsub(/\r|\n/,'')
      end

      def get_mime_type(file)
        MIME::Types.type_for(file.path).empty? ?
          'text\/plain' : MIME::Types.type_for(file.path).first.content_type.gsub(/\//,'\/')
      end

      def set_attachment_attr(args)
        content_type = args[:content_type] ? args[:content_type] : get_mime_type(args[:file])
        self['_attachments'][args[:name]] = {
          'content-type' => content_type,
          'data'         => encode_attachment(args[:file].read)
        }
      end
    end

    def self.included(receiver)
      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
      receiver.class_eval do

        attr_reader :attributes
        cattr_accessor :default_database
        class_inheritable_accessor :class_database
        class_inheritable_accessor :default_obj
        class_inheritable_accessor :casts
        class_inheritable_accessor :design_doc
        class_inheritable_accessor :design_doc_slug_cache
        class_inheritable_accessor :design_doc_fresh

        alias :new_record? :new_document?
        def initialize attrs = {}
          @attributes = CouchRest::Document.new(attrs)
          apply_defaults
          cast_keys
          unless self['_id'] && self['_rev']
            @attributes['couchrest-type'] = self.class.to_s
          end
        end

        include ::Extlib::Hook
        register_instance_hooks :save, :create, :update, :destroy
      end
    end
  end
end