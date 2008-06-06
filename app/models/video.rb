class Video < SimpleDB::Base
  set_domain 'panda_videos'
  
  # SimpleDB
  attr_accessor :key, :multimap
  
  def initialize(key=nil, multimap_or_hash=nil)
    self.key = (key || UUID.new)
    self.multimap = multimap_or_hash.nil? ? Amazon::SDB::Multimap.new : (multimap_or_hash.kind_of?(Hash) ? Amazon::SDB::Multimap.new(multimap_or_hash) : multimap_or_hash)
  end
  
  def self.create(values)
    self.key = UUID.new
    self.multimap = Amazon::SDB::Multimap.new(*values)
    self.new(key, multimap)
  end
  
  def self.create!(values)
    video = self.create(values)
    video.save
    video
  end
  
  def [](key)
    self.multimap[key]
  end
  
  def []=(key, value)
    self.multimap[key] = value
  end
  
  def save
    self.domain.put_attributes(self.key, self.multimap, :replace => :all)
  end
  
  def self.find(key)
    self.new(key, self.domain.get_attributes(key))
  end
  
  def self.query(query_options)
    result = []
    self.domain.query(query_options).each do |i|
      result << self.new(i.key, i.attributes)
    end
    return result
  end
  
  # Video specific stuff
  
end