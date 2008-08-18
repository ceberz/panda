class AddModelFormats < ActiveRecord::Migration
  def self.up
    create_table :formats do |t|
      t.column :name, :string
      t.column :quality, :string # low, med, hi, hd
      
      t.column :resolution, :string
      t.column :container, :string # flv, mp4, mov
      t.column :fps, :string
      t.column :video_codec, :string
      t.column :video_bitrate, :integer
      t.column :audio_codec, :string
      t.column :audio_sample_rate, :integer
      
      t.column :updated_at, :datetime
      t.column :created_at, :datetime
    end
  end

  def self.down
    drop_table :formats
  end
end
