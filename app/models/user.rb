class User < SimpleDB::Base
  set_domain 'panda_users'
  attr_accessor :password, :password_confirmation
  
  def login
    self.key
  end
  
  def self.authenticate(login, password)
    return nil unless u = self.find(login)
    puts "#{u.crypted_password} | #{encrypt(password, u['salt'])}"
    u && (u.crypted_password == encrypt(password, u['salt'])) ? u : nil
  end

  def self.encrypt(password, salt)
    Digest::SHA1.hexdigest("--#{salt}--#{password}--")
  end
  
  def set_password(password)
    return if password.blank?
    salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{self.key}--")
    self.attributes['salt'] = salt
    self.attributes['crypted_password'] = self.class.encrypt(password, salt)
  end
end