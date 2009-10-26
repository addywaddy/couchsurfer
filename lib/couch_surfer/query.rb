module CouchSurfer
  module Query
    module ClassMethods
      def query_processor(name)
        self.external = name
      end
      def query(view_name, query_string, query_options = {})
        payload = {
          :design => self.send(:design_doc_slug),
          :view => set_view_options(view_name, query_options),
          :external => set_external_options(query_string),
        }
        result = CouchRest.post "http://#{database}/_mix", payload
        result['rows'].collect{|r|new(r['doc'])} if result['rows']
      end

      private

      def set_view_options(view_name, query_options)
        {:name => view_name, :query => {:include_docs => true}.merge(query_options)}
      end

      def set_external_options(query_string)
        {:name =>  external, :query =>  {:q =>  query_string}, :include_docs =>  true}
      end
    end
    def self.included(receiver)
      receiver.extend         ClassMethods
      receiver.class_eval do
        class_inheritable_accessor :external
      end
    end
  end
end
