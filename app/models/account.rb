class Account < ActiveRecord::Base
  attr_accessor :password # Virtual attribute for the unencrypted password
  attr_accessor :password_confirmation
  
  validates_presence_of     :login, :email
  validates_presence_of     :password                   #,:if => :password_required?
  validates_presence_of     :password_confirmation      #,:if => :password_required?
  validates_length_of       :password, :within => 4..40 #,:if => :password_required?
  validates_confirmation_of :password                   #,:if => :password_required?
  validates_length_of       :login,    :within => 3..40
  validates_length_of       :email,    :within => 3..100
  validates_uniqueness_of   :login, :email, :case_sensitive => false
  validates_format_of(:email, 
                      :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i, 
                      :message=>"is invalid")
  
  before_save :encrypt_password
  before_create :set_token
  
  has_many :videos
  has_many :jobs, :through => :videos
  
  belongs_to :format
  
  def set_token
    self.token = UUID.new
  end
  
  def upload_redirect_url_or_default
    self.upload_redirect_url.blank? ? "http://#{PANDA_UPLOAD_DOMAIN}/videos/done" : self.upload_redirect_url
  end
  
  def recent_videos
    self.videos.find(:all, :order => "created_at desc", :limit => 25)
  end
  
  # def all_completed_videos
  #   self.videos.find(:all, :conditions => "status = 'done'", :order => "created_at desc")
  # end
  
  def recently_completed_videos
    self.videos.find(:all, :conditions => "status = 'done'", :order => "created_at desc", :limit => 5)
  end
  
  def queued_videos
    self.videos.find(:all, :conditions => "status = 'queued' or status = 'processing'", :order => "created_at asc")
  end
  
  # Auth plugin

  def self.authenticate(params)
    return nil unless u = find_by_login(params[:login]) # need to get the salt
    puts "#{u.crypted_password} | #{encrypt(params[:password], u.salt)}"
    u && (u.crypted_password == encrypt(params[:password], u.salt)) ? u : nil
  end

  def self.encrypt(password, salt)
    Digest::SHA1.hexdigest("--#{salt}--#{password}--")
  end

protected

  def encrypt_password
    return if password.blank?
    self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{login}--") if new_record?
    self.crypted_password = self.class.encrypt(password, self.salt)
  end
end