class AddModelVideos < ActiveRecord::Migration
  def self.up
    create_table :videos do |t|
      t.column :account_id, :integer 
      t.column :token, :string 
      t.column :filename, :string 
      
      t.column :resolution, :string
      t.column :duration, :integer
      t.column :container, :string
      t.column :fps, :string
      t.column :video_codec, :string
      t.column :video_bitrate, :integer
      t.column :audio_codec, :string
      t.column :audio_sample_rate, :integer
      
      t.column :status, :string # NULL or 'uploaded'
      t.column :updated_at, :datetime
      t.column :created_at, :datetime
    end
    
    create_table :encodings do |t|
      t.column :video_id, :integer
      t.column :format_id, :integer
      
      t.column :duration, :integer # For free accounts we might restrict the duration of encodings
      
      # Copied from Format for safe keeping
      t.column :resolution, :string
      t.column :container, :string
      t.column :fps, :string
      t.column :video_codec, :string
      t.column :video_bitrate, :integer
      t.column :audio_codec, :string
      t.column :audio_sample_rate, :integer
      
      t.column :status, :string # 'encoding', 'error' or 'done'
      t.column :encoding_time, :integer # Time it took to encode the video in seconds
      t.column :updated_at, :datetime
      t.column :created_at, :datetime
    end
  end

  def self.down
    drop_table :videos
    drop_table :encodings
  end
end
