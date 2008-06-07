class Video < SimpleDB::Base
  set_domain 'panda_videos'
  properties :filename, :original_filename, :original, :status, :duration, :container, :width, :height, :video_codec, :video_bitrate, :fps, :audio_codec, :audio_sample_rate, :encoding_profile, :encoding_profile_title, :updated_at, :created_at
  attr_accessor :raw_filename # Used when uploading video files
  
  # TODO: state machine for status
  # An original video can either be 'empty' if it hasn't had the video file uploaded, or 'original' if it has
  # An encoding will have it's original attribute set to the key of the original parent, and a status of 'queued', 'processing', 'done', or 'error'
  
  def to_sym
    'videos'
  end
  # Finders
  # =======
  
  def self.queued_videos
    self.query("['status' = 'processing' or 'status' = 'queued']")
  end
  
  def self.recently_completed_videos
    self.query("['status' = 'done']")
  end
  
  # Attr helpers
  # ============
  
  # Has the actual video file been uploaded for encoding?
  def empty?
    self.status == 'empty'
  end
  
  def upload_redirect_url
    UPLOAD_REDIRECT_URL.gsub(/\$id/,self.key)
  end
  
  def duration_str
    s = (self.duration.to_i || 0) / 1000
    "#{sprintf("%02d", s/60)}:#{sprintf("%02d", s%60)}"
  end
  
  # Uploads
  # =======
  
  def process
    self.valid?
    self.read_metadata
    self.upload_to_s3
    self.add_to_queue
  end
  
  def valid?
    raise NotValid unless self.empty?
  end
  
  def read_metadata
    Rog.log :info, "#{self.key}: Meading metadata of video file"
    
    inspector = RVideo::Inspector.new(:file => @raw_filename)

    raise FormatNotRecognised unless inspector.valid? and inspector.video?

    self.duration = (inspector.duration rescue nil)
    self.container = (inspector.container rescue nil)
    self.width = (inspector.width rescue nil)
    self.height = (inspector.height rescue nil)

    self.video_codec = (inspector.video_codec rescue nil)
    self.video_bitrate = (inspector.bitrate rescue nil)
    self.fps = (inspector.fps rescue nil)
    
    self.audio_codec = (inspector.audio_codec rescue nil)
    self.audio_sample_rate = (inspector.audio_sample_rate rescue nil)
    
    raise FormatNotRecognised if self.width.nil? or self.height.nil? # Little final check we actually have some usable video
  end
  
  def upload_to_s3
    Rog.log :info, "#{self.key}: Uploading video to S3"
    
    begin
      retryable(:tries => 2) do
        S3RawVideoObject.store(self.filename, File.open(@raw_filename), :access => :private)
      end
    rescue
      Rog.log :info, "#{self.key}: Error with S3"
      raise
    end
  end
  
  def add_to_queue
    # TODO
  end
  
  # Exceptions
  
  class VideoError < StandardError; end
  
  # 404
  class NotValid < VideoError; end
  
  # 500
  class NoFileSubmitted < VideoError; end
  class FormatNotRecognised < VideoError; end
end