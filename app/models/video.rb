class Video < SimpleDB::Base
  set_domain 'panda_videos'
  properties :filename, :original_filename, :parent, :status, :duration, :container, :width, :height, :video_codec, :video_bitrate, :fps, :audio_codec, :audio_sample_rate, :profile, :profile_title, :updated_at, :created_at
  
  # TODO: state machine for status
  # An original video can either be 'empty' if it hasn't had the video file uploaded, or 'original' if it has
  # An encoding will have it's original attribute set to the key of the original parent, and a status of 'queued', 'processing', 'done', or 'error'
  
  def to_sym
    'videos'
  end
  
  # Finders
  # =======
  
  # Only parent videos (no encodings)
  def self.all
    self.query("['status' = 'original']")
  end
  
  def self.queued_videos
    self.query("['status' = 'processing' or 'status' = 'queued']")
  end
  
  def self.recently_completed_videos
    self.query("['status' = 'done']")
  end
  
  def encodings
    self.class.query("['parent' = '#{self.key}']")
  end
  
  # Attr helpers
  # ============
  
  # Location to store video file fetched from S3 for encoding
  def tmp_filepath
    Panda::Config[:tmp_video_dir] / self.filename
  end
  
  # Has the actual video file been uploaded for encoding?
  def empty?
    self.status == 'empty'
  end
  
  def upload_redirect_url
    Panda::Config[:upload_redirect_url].gsub(/\$id/,self.key)
  end
  
  def duration_str
    s = (self.duration.to_i || 0) / 1000
    "#{sprintf("%02d", s/60)}:#{sprintf("%02d", s%60)}"
  end
  
  def resolution
    self.width ? "#{self.width}x#{self.height}" : nil
  end
  
  def video_bitrate_in_bits
    self.video_bitrate * 1024
  end
  
  def audio_bitrate_in_bits
    self.audio_bitrate * 1024
  end
  
  # S3
  # ==
  
  def upload_to_s3(access = :private)
    Rog.log :info, "#{self.key}: Uploading video to S3"
    
    begin
      retryable(:tries => 5) do
        S3RawVideoObject.store(self.filename, File.open(self.tmp_filepath), :access => access)
      end
    rescue
      Rog.log :info, "#{self.key}: Error with S3"
      raise
    end
  end
  
  def fetch_from_s3
    begin
      retryable(:tries => 5) do
        open(self.tmp_filepath, 'w') do |file|
          S3RawVideoObject.stream(self.filename) {|chunk| file.write chunk}
        end
      end
    rescue
      raise
    end
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
    
    inspector = RVideo::Inspector.new(:file => self.tmp_filepath)

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
    
    # raise FormatNotRecognised if self.width.nil? or self.height.nil? # Little final check we actually have some usable video
  end
  
  def add_to_queue
    # TODO: Allow manual selection of encoding profiles used in both form and api
    # For now we will just encode to all available profiles
    Profile.query.each do |p|
      cur_video = Video.query("['parent' = '#{self.key}'] intersection ['profile' = '#{p.key}']")
      unless cur_video
        # TODO: move to a method like self.add_encoding
        encoding = Video.new
        encoding[:profile] = p.key
        encoding[:profile_title] = p.title
        encoding[:status] = 'queued'
        encoding[:parent] = self.key
        [:original_filename, :duration, :container, :width, :height, :video_codec, :video_bitrate, :fps, :audio_codec, :audio_bitrate, :audio_sample_rate].each do |k|
          encoding.put(k, p.get(k))
        end
        encoding[:filename] = "#{encoding.key}.#{p.container}"
        encoding.save
      end
    end
    
    # Add job to queue
    Queue.encodings.send_message(self.key)
  end
  
  # Exceptions
  
  class VideoError < StandardError; end
  
  # 404
  class NotValid < VideoError; end
  
  # 500
  class NoFileSubmitted < VideoError; end
  class FormatNotRecognised < VideoError; end
  
  # Encoding
  # ========
  
end