SimpleDB::Base.establish_connection!(
  :access_key_id     => Panda::Config[:access_key_id],
  :secret_access_key => Panda::Config[:secret_access_key]
)

AWS::S3::Base.establish_connection!(
  :access_key_id     => Panda::Config[:access_key_id],
  :secret_access_key => Panda::Config[:secret_access_key]
)

class S3VideoObject < AWS::S3::S3Object
  set_current_bucket_to Panda::Config[:s3_videos_bucket]
end