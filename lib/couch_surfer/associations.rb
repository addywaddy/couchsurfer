require 'rubygems'
require 'extlib'
module CouchSurfer
  class InlineCollection < Array
    def << child
      child = child.kind_of?( CouchSurfer::Model) ? child.attributes : child
      super(child)
    end
    
    def delete(child)
      child = child.kind_of?( CouchSurfer::Model) ? child.attributes : child
      super(child)
    end
  end
end
module CouchSurfer
  module Associations
    module ClassMethods
      def has_many *args
        options = extract_options!(args)
        children = args.first
        if options[:inline]
          name =  ::Extlib::Inflection.camelize(children.to_s.singular)
          cast children, :as => [name]
          before(:save) do
            if self[children.to_s]
              self[children.to_s].map!{|child| child.kind_of?( CouchSurfer::Model) ? child.attributes : child}
            end
          end
          define_method children do |*args|
            self[children.to_s] ||= CouchSurfer::InlineCollection.new
          end
          return
        end
        if options[:through]
          define_method_for_children(options[:through], options)
          define_method children do
            name = (options[:class_name] || children).to_s.singular
            class_name =  ::Extlib::Inflection.camelize(name)
            klass = ::Extlib::Inflection.constantize(class_name)
            through_items = self.send("#{options[:through]}")
            query ||= {:keys => through_items.map{|child| child.send("#{name}_id")}}
            view_name ||= "by_#{self.class.name.downcase}_id"
            klass.send("all", query)
          end
          return
        end
        define_method_for_children(children, options, options[:class_name])
      end
      
      def belongs_to *args
        options = extract_options!(args)
        parent = args.first
        parent_name = (options[:class_name] || parent).to_s
        define_method parent do
          class_name = ::Extlib::Inflection.camelize(parent_name)
          klass = ::Extlib::Inflection.constantize(class_name)
          parent_id = self["#{parent_name}_id"]
          if parent_id
            klass.send(:get, self["#{parent_name}_id"])
          end
        end

        define_method "#{parent}=".to_sym do |parent_obj|
          self["#{parent_obj.class.name.downcase}_id"] = parent_obj.id
        end
      end
      
      private
      
      def extract_options!(args)
        args.last.is_a?(Hash) ? args.pop : {}
      end
      
      def define_method_for_children(children, options, name = nil)
        class_name =  ::Extlib::Inflection.camelize(name || children.to_s.singular)
        define_method children do
          klass = ::Extlib::Inflection.constantize(class_name)
          if options[:view]
            view_name = options[:view]
          end
          if options[:query].is_a?(Proc)
             query = self.instance_eval(&options[:query])
          end
          view_name ||= "by_#{self.class.name.downcase}_id"
          query ||= {:key => self.id}
          klass.send(view_name, query)
        end
      end
    end
    
    def self.included(receiver)
      receiver.extend         ClassMethods
    end
  end
end