class ChangeEncodings < ActiveRecord::Migration
  def self.up
    remove_column :encodings, :video_codec
    remove_column :encodings, :audio_codec
    rename_column :encodings, :audio_sample_rate, :audio_bitrate
  end

  def self.down
  end
end
