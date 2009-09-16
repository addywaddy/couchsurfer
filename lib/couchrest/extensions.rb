module CouchRest
  class Database
    # Query a CouchDB view as defined by a <tt>_design</tt> document. Accepts
    # paramaters as described in http://wiki.apache.org/couchdb/HttpViewApi
    #/db/_design/examples/_list/index-posts/posts-by-date
    
    def list(list_name, view_name, doc_name, params = {})
      url = CouchRest.paramify_url "#{@uri}/_design/#{doc_name}/_list/#{list_name}/#{view_name}", params
      response = RestClient.get(url)
      JSON.parse(response)
    rescue
      response
    end
  end

  class Design
    # Dispatches to any named view.
    # (using the database where this design doc was saved)
    def list(list_name, view_name, query = {})
      database.list(list_name, view_name.to_s, name, query)
    end

    # Dispatches to any named view.
    # (using the database where this design doc was saved)
    def view view_name, query={}, &block
      view_on database, view_name, query, &block
    end

    # Dispatches to any named view in a specific database
    def view_on db, view_name, query={}, &block
      view_name = view_name.to_s
      view_slug = "#{name}/#{view_name}"
      defaults = (self['views'][view_name] && self['views'][view_name]["couchrest-defaults"]) || {}
      db.view(view_slug, defaults.merge(query), &block)
    end

    private

    # returns stored defaults if the there is a view named this in the design doc
    def has_view?(view)
      view = view.to_s
      self['views'][view] &&
        (self['views'][view]["couchrest-defaults"]||{})
    end

    def fetch_view view_name, opts, &block
      database.view(view_name, opts, &block)
    end

  end
end