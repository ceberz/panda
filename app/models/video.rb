class Video < ActiveRecord::Base
  belongs_to :account
  
  has_many :encodings, :dependent => :destroy
  has_many :jobs, :dependent => :destroy
  
  before_create :set_default_status
  before_create :set_token
  before_destroy :delete_s3_files
  
  def set_default_status
    self.status = 'empty'
  end
  
  def empty?
    self.status == "empty"
  end
  
  def set_token
    self.token = UUID.new
  end
  
  def default_flv_url
    self.encodings.first.url
  end
  
  def full_raw_path
    File.join(RAW_DIR,self.token)
  end
  
  def duration_str
    s = (self.duration || 0) / 1000
    "#{sprintf("%02d", s/60)}:#{sprintf("%02d", s%60)}"
  end

  def resolution
    self.width ? "#{self.width}x#{self.height}" : nil
  end
  
  def upload_form_url
    %(http://#{PANDA_UPLOAD_DOMAIN}:#{PANDA_UPLOAD_PORT}/videos/#{self.token}/form)
  end
  
  def show_response
    {:video => {
        :id => self.token,
        :resolution => self.resolution,
        :duration => self.duration,
        :status => self.status,
        :encodings => self.encodings.map {|e| e.show_response}
      }
    }
  end
  
  def create_response
    {:video => {
        :id => self.token
      }
    }
  end
  
  def job_response
    {:token => self.token,
      :status => self.status,
      :encodings => self.encodings.map {|e| e.job_response}
    }
  end
  
  def change_status(st)
    self.update_attribute(:status, st.to_s)
  end
  
  def add_to_queue
    job = self.jobs.create 
    self.change_status(:queued)
    self.send_status
    return job
  end
    
  # TODO: Use notifications daemon
  def send_status
    url = self.account.state_update_url.gsub(/\$id/,self.token)
    # params = {"video" => self.show_response.to_yaml}
    
    Rog.log :info, "Sending status update of video##{self.token} to client (#{self.account.login}): #{url}"
    
    begin
      ressult = Net::HTTP.get_response(URI.parse(url))
      puts "--> #{result.code} #{result.message} (#{result.body.length})"
      puts "WOULD FETCH URL NOW: #{url}"
    rescue
      puts "Couldn't connect to #{url}"
      # TODO: Send back a nice error if we can't connect to the client
    end
  end
  
  def save_metadata(metadata)
    [:width, :height, :duration, :container, :fps, :video_codec, :video_bitrate, :audio_codec, :audio_sample_rate].each do |x|
      self.send("#{x}=", metadata[x])
    end
  end
  
  def add_encoding_for_quality(quality, force=nil)
    # Only create an encoding if it doesn't already exist for this format
    unless Encoding.find(:first, :conditions => {:video_id => self.id, :quality_id => quality.id})
      if force == :force or self.width >= quality.width
        status = "queued"
        Encoding.create(:token => UUID.new, :video_id => self.id, :quality_id => quality.id, :status => status)
      end
    end
  end
  
  def add_encodings
    # TODO: Only add formats which the user has added to their account
    Format.find(:all).each do |format|
      qualities = format.qualities
      # We always encode to the lowest quality (which will be the first, as they are ordered)
      self.add_encoding_for_quality(qualities.shift, :force)
      qualities.each do |quality|
        self.add_encoding_for_quality(quality)
      end
    end
  end
  
  def delete_s3_files
    S3RawVideoObject.delete(self.token)
    self.encodings.each do |e|
      S3VideoObject.delete(e.filename)
    end
  end
  
  # def upload_and_encode(filename, format)  
    # encoding = self.encodings.create(:format_id => format.id)
    
    # Send to uploading queue
    # message = {:filename => filename, :token => self.token, :encoding => encoding.hash_for_queue}
    # puts "Adding to upload queue"
    # puts message.to_yaml
    # Queue.up.send_message message.to_yaml
  # end
end