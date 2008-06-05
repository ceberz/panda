class ChangeQualities < ActiveRecord::Migration
  def self.up
    remove_column :qualities, :video_codec
    remove_column :qualities, :audio_codec
    rename_column :qualities, :audio_sample_rate, :audio_bitrate
  end

  def self.down
  end
end
