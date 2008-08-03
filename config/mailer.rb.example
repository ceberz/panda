require 'tlsmail' # gem install tlsmail
Net::SMTP.enable_tls(OpenSSL::SSL::VERIFY_NONE)

Merb::Mailer.config = {
  :host   => 'smtp.gmail.com',
  :port   => '587',
  :user   => 'myname@gmail.com',
  :pass   => 'mygmailpass',
  :auth   => :plain
}