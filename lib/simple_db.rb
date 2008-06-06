class SimpleDB
  
  class Base
    def self.establish_connection!(opts)
      @@connection = Amazon::SDB::Base.new(opts[:access_key_id], opts[:secret_access_key])
    end
    
    def self.connection; @@connection; end
    
    def self.set_domain(domain)
      @@domain = domain
    end
    
    def domain
      @@connection.domain(@@domain)
    end
    
    def self.domain
      @@connection.domain(@@domain)
    end
  end
end