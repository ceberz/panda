class Encoding < ActiveRecord::Base
  belongs_to :video
  belongs_to :quality
  
  has_many :notifications
  
  before_create :copy_metadata
  before_create :set_pending_status
  
  def filename
    "#{self.token}.#{self.container}"
  end
  
  def full_path
    File.join(ENCODED_DIR,self.filename)
  end
  
  def url
    # FIXME: only return the flv encoding
    "http://#{PANDA_VIDEOS_DOMAIN}/#{self.filename}"
  end
  
  def embed_html
    %(<embed src="http://#{PANDA_VIDEOS_DOMAIN}/flvplayer.swf" width="#{self.width}" height="#{self.height}" allowfullscreen="true" allowscriptaccess="always" flashvars="&displayheight=#{self.height}&file=#{self.url}&width=#{self.width}&height=#{self.height}" />)
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
  
  def copy_metadata
    [:width, :height, :container, :fps, :video_bitrate, :audio_bitrate].each do |x|
      self.send("#{x}=", self.quality.send(x))
    end
  end
  
  def show_response
    {
      :id => self.token,
      :width => self.width,
      :height => self.height,
      :resolution => self.resolution,
      :duration => self.duration,
      :format => self.quality.format.code,
      :quality => self.quality.quality,
      :status => self.status,
      :filename => self.filename
     }
  end
  
  def job_response
    hash = {}
    [:id, :token, :filename, :status, :width, :height, :resolution, :container, :fps, :video_bitrate, :video_bitrate_in_bits, :audio_bitrate, :audio_bitrate_in_bits].each do |x|
      hash[x] = self.send(x)
    end
    hash[:format] = self.quality.format.code
    hash[:quality] = self.quality.quality
    return hash
  end
  
  def change_status(st)
    self.update_attribute(:status, st.to_s)
  end
  
  def set_pending_status
    self.status = 'queued'
  end
end