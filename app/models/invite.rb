class Invite < ActiveRecord::Base
  belongs_to :account
  
  validates_presence_of     :email
  validates_length_of       :email, :within => 3..100
  validates_uniqueness_of   :email, :case_sensitive => false
  validates_format_of(:email, 
                      :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i, 
                      :message=>"is invalid")
  
  def approve!
    self.update_attribute(:approved, Time.now)
    InviteMailer.new.dispatch_and_deliver(:approved, {
                :from => EMAIL_SENDER,
                :to => self.email,
                :subject => "Welcome to the Panda beta"
              })
  end
end