class Profile < SimpleDB::Base
  set_domain 'panda_profiles'
  properties :title, :container, :width, :height, :video_codec, :video_bitrate, :fps, :audio_codec, :audio_sample_rate, :updated_at, :created_at
end