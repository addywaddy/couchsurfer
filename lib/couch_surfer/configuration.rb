module CouchSurfer
  class Configuration
    @@host = nil
    #cattr_accessor :host
    def self.host
      @@host
    end

    def self.host=(host)
      @@host = host
    end
  end
end