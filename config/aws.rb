SimpleDB::Base.establish_connection!(
  :access_key_id     => Panda::Config[:access_key_id],
  :secret_access_key => Panda::Config[:secret_access_key]
)
