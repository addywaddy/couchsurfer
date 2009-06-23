require 'validatable'

module CouchSurfer
  module Validations
    module ClassMethods
      def validates_uniqueness_of *args
        # add view, validation and before callbacks
        options = args.last.is_a?(Hash) ? args.pop : {}
        field = args.first
        class_eval do
          #view_by *args
          validates_true_for args.first, :logic => lambda { is_unique?(field, options) }, :message => options[:message] || "is taken"
        end
      end
    end
    
    module InstanceMethods
      def is_unique?(field, options)
        if options[:view]
          view_name = options[:view]
          query     = options[:query].is_a?(Proc) ? self.instance_eval(&options[:query]) : nil
        end
        view_name ||= "by_#{field}"
        query ||= {:key => self.send(field)}
        result = self.class.send(view_name, query)
        if result.blank?
          return true
        else
          return !id.blank? && (id == result.first.id)
        end
      end
      
      def validate_instance
        throw(:halt, false) unless valid?
      end
    end

    def self.included(receiver)
      receiver.extend ClassMethods
      receiver.send :include, Validatable
      receiver.send :include, InstanceMethods
      receiver.class_eval do
        [:save].each do |method|
          before method, :validate_instance
        end
      end
    end
  end
end