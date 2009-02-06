$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

module CouchSurfer
  VERSION = '0.0.5'
  autoload :Model,        'couch_surfer/model'
  autoload :Validations,        'couch_surfer/validations'
  autoload :Associations,        'couch_surfer/associations'
end