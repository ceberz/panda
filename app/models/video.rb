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
    q = SQS.get_queue :name => 'panda_encoding'
    q.send_message(self.key)
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
  
  def ffmpeg_resolution_and_padding(inspector, encoding, log)
    # Calculate resolution and any padding
    in_w = inspector.width.to_f
    in_h = inspector.height.to_f
    out_w = encoding.width.to_f
    out_h = encoding.height.to_f

    begin
      aspect = in_w / in_h
    rescue
      Merb.logger :error,  "Couldn't do w/h to caculate aspect. Just using the output resolution now."
      return %(-s #{encoding.width}x#{encoding.height})
    end

    height = (out_w / aspect.to_f).to_i
    height -= 1 if height % 2 == 1

    opts_string = %(-s #{encoding.width}x#{height} )

    # Crop top and bottom is the video is too tall, but add top and bottom bars if it's too wide (aspect wise)
    if height > out_h
      crop = ((height.to_f - out_h) / 2.0).to_i
      crop -= 1 if crop % 2 == 1
      opts_string += %(-croptop #{crop} -cropbottom #{crop})
    elsif height < out_h
      pad = ((out_h - height.to_f) / 2.0).to_i
      pad -= 1 if pad % 2 == 1
      opts_string += %(-padtop #{pad} -padbottom #{pad})
    end

    return opts_string
  end

  def encode
    Merb.logger.info "=========================================================="
    Merb.logger.info Time.now.to_s
    Merb.logger.info "=========================================================="
    Merb.logger.info "Beginning encoding of video #{self.key}"
    begun_encoding = Time.now

    self.status = 'encoding'
    self.save

    Merb.logger.info self.attributes.to_h.to_yaml

    Merb.logger.info "Grabbing raw video from S3"
    self.fetch_from_s3

    self.encodings.each do |encoding|
      Merb.logger.info "Beginning encoding:"
      Merb.logger.info encoding.attributes.to_h.to_yaml

      Merb.logger.info "Encoding #{encoding.key}"

      # Encode video
      Merb.logger.info "Encoding self..."
      inspector = RVideo::Inspector.new(:file => self.tmp_filepath)
      transcoder = RVideo::Transcoder.new

      recipe_options = {:input_file => self.tmp_filepath, :output_file => encoding.tmp_filepath, 
        :audio_bitrate => encoding.audio_bitrate.to_s, 
        :audio_bitrate_in_bits => encoding.audio_bitrate_in_bits.to_s, 
        :container => encoding.container, 
        :video_bitrate_in_bits => encoding.video_bitrate_in_bits.to_s, 
        :resolution => encoding.resolution,
        :resolution_and_padding => ffmpeg_resolution_and_padding(inspector, encoding, log)
        }

      Merb.logger.info recipe_options.to_yaml

      # begin
        case encoding.container
        when "flv"
          recipe = "ffmpeg -i $input_file$ -ar 22050 -ab $audio_bitrate$k -f flv -b $video_bitrate_in_bits$ -r 22 $resolution_and_padding$ -y $output_file$"
          recipe += "\nflvtool2 -U $output_file$"
          transcoder.execute(recipe, recipe_options)
        when "flash-h264"
          # Just the video without audio
          temp_video_output_file = "#{encoding.tmp_filepath}.temp.self.mp4"
          temp_audio_output_file = "#{encoding.tmp_filepath}.temp.audio.mp4"
          temp_audio_output_wav_file = "#{encoding.tmp_filepath}.temp.audio.wav"

          recipe = "ffmpeg -i $input_file$ -an -vcodec libx264 -crf 28 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.6 -qmin 10 -qmax 51 -qdiff 4 -coder 1 -flags +loop -cmp +chroma -partitions +parti4x4+partp8x8+partb8x8 -me hex -subq 5 -me_range 16 -g 250 -keyint_min 25 -sc_threshold 40 -i_qfactor 0.71 $resolution_and_padding$ -r 22 -y $output_file$"
          recipe_audio_extraction = "ffmpeg -i $input_file$ -ar 48000 -ac 2 -y $output_file$"

          transcoder.execute(recipe, recipe_options.merge({:output_file => temp_video_output_file}))
          Merb.logger.info "Video encoding done"

          if inspector.audio?
            # We have to use nero to encode the audio as ffmpeg doens't support HE-AAC yet
            transcoder.execute(recipe_audio_extraction, recipe_options.merge({:output_file => temp_audio_output_wav_file}))
            Merb.logger.info "Audio extraction done"

            # Convert to HE-AAC
            %x(neroAacEnc -br #{encoding[:audio_bitrate_in_bits]} -he -if #{temp_audio_output_wav_file} -of #{temp_audio_output_file})
            Merb.logger.info "Audio encoding done"
            Merb.logger.info Time.now

            # Squash the audio and video together
            FileUtils.rm(encoding.tmp_filepath) if File.exists?(encoding.tmp_filepath) # rm, otherwise we end up with multiple video streams when we encode a few times!!
            %x(MP4Box -add #{temp_video_output_file}#video #{encoding.tmp_filepath})
            %x(MP4Box -add #{temp_audio_output_file}#audio #{encoding.tmp_filepath})

            # Interleave meta data
            %x(MP4Box -inter 500 #{encoding.tmp_filepath})
            Merb.logger.info "Squashing done"
          else
            Merb.logger.info "This video does't have an audio stream"
            FileUtils.mv(temp_video_output_file, encoding.tmp_filepath)
          end
          Merb.logger.info Time.now
        else
          # log.warn "Error: unknown encoding format given"
          Merb.logger :error, "Couldn't encode #{encoding.key}. Unknown encoding format given."
        end

        Merb.logger.info "Done encoding"

        # Now upload it to S3
        if File.exists?(encoding.tmp_filepath)
          Merb.logger.info "Success encoding #{encoding.filename}. Uploading to S3."
          Merb.logger.info "Uploading #{encoding.filename}"

          encoding.upload_to_s3
          FileUtils.rm encoding.tmp_filepath

          Merb.logger.info "Done uploading"

          # Update the encoding data which will be returned to the server
          encoding.status = "success"
        else
          encoding.status = "error"
          Merb.logger.info "Couldn't upload #{encoding.key} to S3 as #{encoding.tmp_filepath} doesn't exist."
          # log.warn "Error: Cannot upload as #{encoding.tmp_filepath} does not exist"
        end

        # encoding[:executed_commands] = transcoder.executed_commands
      # rescue RVideo::TranscoderError => e
      #   encoding.status = "error"
      #   # encoding[:executed_commands] = transcoder.executed_commands
      #   Merb.logger :error, "Error transcoding #{encoding[:id]}: #{e.class} - #{e.message}"
      #   Merb.logger.info "Unable to transcode file #{encoding[:id]}: #{e.class} - #{e.message}"
      # end
    end

    Merb.logger.info "All encodings complete!"
    Merb.logger.info "Complete!"
    FileUtils.rm self.tmp_filepath
    encoding.encoding_time = Time.now - begun_encoding
    return true
  end
end