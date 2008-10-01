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

require "config" / "panda_init"

dependencies 'merb-assets', 'merb-mailer', 'merb_helpers', 'uuid', 'to_simple_xml', 'rog', 'amazon_sdb', 'simple_db', 'retryable', 'activesupport', 'rvideo', 'panda', 'gd_resize', 'map_to_hash', 'spec_eql_hash', 'error_sender'

dependencies 'abstract_store', 's3_Store'

# Not sure why dependencies won't load AWS::S3
require 'aws/s3'
require 'inline'

Merb::BootLoader.after_app_loads do
  # Panda specific

  unless Merb.environment == "test"
    require "config" / "aws"
    require "config" / "mailer" # If you want notification and encoding errors to be sent to you as well as logged
  end

# Overwriding form, as SimpleDB does not provide errors on object.
  module Merb::Helpers::Form
    def _singleton_form_context
      self._default_builder = Merb::Helpers::Form::Builder::ResourcefulForm
      @_singleton_form_context ||=
        self._default_builder.new(nil, nil, self)
    end
  end
  
  Store = S3Store.new
end

EMAIL_SENDER = "Panda <info@pandastream.com>"
