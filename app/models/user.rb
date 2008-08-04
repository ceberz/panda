class User < SimpleDB::Base
  set_domain Panda::Config[:sdb_users_domain]
  properties :password, :email, :salt, :crypted_password, :api_key, :updated_at, :created_at
  attr_accessor :password, :password_confirmation
  
  def login
    self.key
  end
  
  def login=(v)
    self.key = v
  end
  
  def self.authenticate(login, password)
    begin
      u = self.find(login) # Login is the key of the SimpleDB object
    rescue Amazon::SDB::RecordNotFoundError
      return nil
    else
      puts "#{u.crypted_password} | #{encrypt(password, u.salt)}"
      u && (u.crypted_password == encrypt(password, u.salt)) ? u : nil
    end
  end

  def self.encrypt(password, salt)
    Digest::SHA1.hexdigest("--#{salt}--#{password}--")
  end
  
  def set_password(password)
    return if password.blank?
    salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{self.key}--")
    self.salt = salt
    self.crypted_password = self.class.encrypt(password, salt)
  end
end