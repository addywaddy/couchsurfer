require 'rubygems'
require 'extlib'

module CouchSurfer
  module Associations
    module ClassMethods
      def has_many *args
        options = args.last.is_a?(Hash) ? args.pop : {}
        children = args.first
        define_method children do |*args|
          query_params = args.last.is_a?(Hash) ? args.pop : nil
          name =  ::Extlib::Inflection.camelize(children.to_s.singular)
          klass = ::Extlib::Inflection.constantize(name)
          if options[:view].is_a?(Hash)
            view_name = options[:view][:name]
            query     = options[:view][:query].is_a?(Proc) ? self.instance_eval(&options[:view][:query]) : nil
          end
          view_name ||= "by_#{self.class.name.downcase}_id"
          query ||= {:key => self.id}
          klass.send(view_name, query)
        end
      end
      
      def belongs_to *args
        options = args.last.is_a?(Hash) ? args.pop : {}
        parent = args.first
        # view_key = "#{parent}_id".to_sym
        # if options[:identifiers]
        #   if options[:prepend]
        #     view_key = options[:identifiers] << view_key
        #   else 
        #     view_key = options[:identifiers].unshift(view_key)
        #   end
        # end
        # class_eval do
        #   view_by *view_key
        # end
        define_method parent do
          name = ::Extlib::Inflection.camelize(parent.to_s)
          klass = ::Extlib::Inflection.constantize(name)
          parent_id = self["#{parent.to_s}_id"]
          if parent_id
            klass.send(:get, self["#{parent.to_s}_id"])
          end
        end

        define_method "#{parent}=".to_sym do |parent_obj|
          self["#{parent_obj.class.name.downcase}_id"] = parent_obj.id
        end
      end
    end
    
    def self.included(receiver)
      receiver.extend         ClassMethods
    end
  end
end