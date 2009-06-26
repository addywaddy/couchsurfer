$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'rubygems'
require 'extlib'
require 'couchrest'

module CouchSurfer
  VERSION = '0.0.5'
  autoload :Configuration,       'couch_surfer/configuration'
  autoload :Database,       'couch_surfer/database'
  autoload :Model,          'couch_surfer/model'
  autoload :Validations,    'couch_surfer/validations'
  autoload :Associations,   'couch_surfer/associations'
  autoload :Query,          'couch_surfer/query'
end
