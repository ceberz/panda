class Profile < SimpleDB::Base
  set_domain 'panda_profiles'
  properties :title, :player, :container, :width, :height, :video_codec, :video_bitrate, :fps, :audio_codec, :audio_bitrate, :audio_sample_rate, :position, :updated_at, :created_at
end
