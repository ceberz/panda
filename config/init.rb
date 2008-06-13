# Make the app's "gems" directory a place where gems are loaded from
Gem.clear_paths
Gem.path.unshift(Merb.root / "gems")

# Make the app's "lib" directory a place where ruby files get "require"d from
$LOAD_PATH.unshift(Merb.root / "lib")


Merb::Config.use do |c|
  
  ### Sets up a custom session id key, if you want to piggyback sessions of other applications
  ### with the cookie session store. If not specified, defaults to '_session_id'.
  # c[:session_id_key] = '_session_id'
  
  c[:session_secret_key]  = '4d5e9b90d9e92c236a2300d718059aef3a9b9cbe'
  c[:session_store] = 'cookie'
end

# use_orm :activerecord

dependencies 'merb-assets', 'merb-mailer', 'merb_helpers', 'uuid', 'to_simple_xml', 'rog', 'amazon_sdb', 'simple_db', 'retryable', 'activesupport', 'rvideo', 'panda'

# Not sure why dependencies won't load AWS::S3
require 'aws/s3'
require 'sqs'

Merb::BootLoader.after_app_loads do
  # Panda specific

  unless Merb.environment == "test"
    require "config" / "aws"
    
    Merb::Mailer.config = {
      :host=>'localhost',
      :domain => 'pandastream.com',
      :port=>'25'         
      # :user=>'',
      # :pass=>'',
      # :auth=>:plain # :plain, :login, :cram_md5, the default is no auth
    }
  end
  
  Panda::Config.use do |p|
    p[:account_name]           = "New Bamboo"
    p[:api_key]                = "f9e69730-16fd-012b-731d-001ec2b5c0e1"
    p[:upload_redirect_url]    = "http://localhost:4000/videos/$id/done"
    p[:state_update_url]       = "http://localhost:4000/videos/$id/status"
    p[:videos_domain]          = "videos.pandastream.com"
    p[:storage]                = :filesystem # or :s3 # TODO: implement
    p[:tmp_video_dir]          = Merb.root / "videos"
  end
end

EMAIL_SENDER = "Panda <info@pandastream.com>"