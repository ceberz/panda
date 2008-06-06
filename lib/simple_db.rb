class SimpleDB
  
  class Base
    def self.establish_connection!(opts)
      @@connection = Amazon::SDB::Base.new(opts[:access_key_id], opts[:secret_access_key])
    end
    
    def self.connection; @@connection; end
    
    class << self
      attr_accessor :domain_name
    end
    
    def self.domain
      @@connection.domain(self.domain_name)
    end
    
    def self.set_domain(d)
      self.domain_name = d
    end
    
    attr_accessor :key, :attributes

    def initialize(key=nil, multimap_or_hash=nil)
      self.key = (key || UUID.new)
      self.attributes = multimap_or_hash.nil? ? Amazon::SDB::Multimap.new : (multimap_or_hash.kind_of?(Hash) ? Amazon::SDB::Multimap.new(multimap_or_hash) : multimap_or_hash)
    end

    def self.create(values)
      self.key = UUID.new
      self.attributes = Amazon::SDB::Multimap.new(*values)
      self.new(key, attributes)
    end

    def self.create!(values)
      video = self.create(values)
      video.save
      video
    end

    def [](key)
      self.attributes[key]
    end

    def []=(key, value)
      self.attributes[key] = value
    end

    def save
      self.class.domain.put_attributes(self.key, self.attributes, :replace => :all)
    end
    
    def destroy!
      self.class.domain.delete_attributes(self.key)
    end
    
    def reload!
      item = self.class.domain.get_attributes(@key)
      self.attributes = item.attributes
    end

    def self.find(key)
      self.new(key, self.domain.get_attributes(key).attributes)
    end

    def self.query(query_options='')
      result = []
      self.domain.query(query_options).each do |i|
        result << self.new(i.key, i.attributes)
      end
      return result
    end
  end
end