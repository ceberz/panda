# WARNING: This code is procedural bollocks!
# merb -r "panda/lib/encoder.rb"

# Set hostname should probably be in the AMI startup script
%x(set_hostname)

# if MERB_ENV == 'production'
#   PANDA_HOME = "/mnt/panda_encoder"
#   PANDA_RAW_FILES = "/mnt/files/raw"
#   PANDA_ENCODED_FILES = "/mnt/files/encoded"
#   PANDA_DOMAIN = "hq.pandastream.com"
#   PANDA_LOG_SERVER = "127.0.0.1"
#   PANDA_PORT = 80
#   HOSTNAME = %x(hostname).strip
#   AWS_CONNECT_FILE = '/aws_connect'
# else  
#   PANDA_RAW_FILES = File.join(File.dirname(__FILE__), "..","files","raw")
#   PANDA_ENCODED_FILES = File.join(File.dirname(__FILE__), "..","files","encoded")
#   PANDA_DOMAIN = "127.0.0.1"
#   PANDA_LOG_SERVER = "127.0.0.1"
#   PANDA_PORT = 4000
#   HOSTNAME = "localhost"
#   AWS_CONNECT_FILE = File.dirname(__FILE__) + '/../../aws_connect'
# end

# Local detailed logger

require 'log4r'
include Log4r

log = Logger.new 'encqlog'
fileo = FileOutputter.new('fileOutputter', :filename => File.join(File.dirname(__FILE__), 'encoder.log'), :trunc => false)
log.add fileo
log.level = Log4r::DEBUG

log.info 'Encoder awake!'

# New remote logger

require 'rog'
Rog.prefix = "Encoder##{HOSTNAME}"
Rog.host = PANDA_LOG_SERVER
Rog.port = 3333
Rog.log :info, "Panda Encoder app awake"

def ffmpeg_resolution_and_padding(inspector, encoding, log)
  # Calculate resolution and any padding
  in_w = inspector.width.to_f
  in_h = inspector.height.to_f
  out_w = encoding[:width].to_f
  out_h = encoding[:height].to_f

  begin
    aspect = in_w / in_h
  rescue
    log.error "Couldn't do w/h to caculate aspect. Just using the output resolution now."
    return %(-s #{encoding[:width]}x#{encoding[:height]})
  end
  
  height = (out_w / aspect.to_f).to_i
  height -= 1 if height % 2 == 1
  
  opts_string = %(-s #{encoding[:width]}x#{height} )
  
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

def encoding(key,log)
  log.info "=========================================================="
  log.info Time.now
  log.info "=========================================================="
  log.info "Beginning encoding of video #{key}"
  begun_encoding = Time.now
  
  video = Video.find(key)
  video.status = 'encoding'
  video.save
  
  log.info "Grabbing raw video from S3"
  video.fetch_from_s3
  
  Rog.log :info, "job##{job[:id]}: Beginning encodings"
  job[:video][:encodings].each do |encoding|
    log.info "Beginning encoding:"
    log.info encoding.to_yaml
    
    Rog.log :info, "job##{job[:id]}: Encoding #{encoding[:id]}"
    
    enc_fn = File.join(PANDA_ENCODED_FILES, encoding[:filename])
    
    # Encode video
    log.info "Encoding video..."
    inspector = RVideo::Inspector.new(:file => raw_fn)
    transcoder = RVideo::Transcoder.new
    
    recipe_options = {:input_file => raw_fn, :output_file => enc_fn, 
      :audio_bitrate => encoding[:audio_bitrate].to_s, 
      :audio_bitrate_in_bits => encoding[:audio_bitrate_in_bits].to_s, 
      :container => encoding[:container], 
      :video_bitrate => encoding[:video_bitrate_in_bits].to_s, 
      :resolution => encoding[:resolution],
      :resolution_and_padding => ffmpeg_resolution_and_padding(inspector, encoding, log)
      }
    
    log.info recipe_options.to_yaml
    
    begin
      case encoding[:format]
      when "flv"
        recipe = "ffmpeg -i $input_file$ -ar 22050 -ab $audio_bitrate$k -f flv -b $video_bitrate$ -r 22 $resolution_and_padding$ -y $output_file$"
        recipe += "\nflvtool2 -U $output_file$"
        transcoder.execute(recipe, recipe_options)
      when "flash-h264"
        # Just the video without audio
        temp_video_output_file = "#{enc_fn}.temp.video.mp4"
        temp_audio_output_file = "#{enc_fn}.temp.audio.mp4"
        temp_audio_output_wav_file = "#{enc_fn}.temp.audio.wav"
        
        recipe = "ffmpeg -i $input_file$ -an -vcodec libx264 -crf 28 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.6 -qmin 10 -qmax 51 -qdiff 4 -coder 1 -flags +loop -cmp +chroma -partitions +parti4x4+partp8x8+partb8x8 -me hex -subq 5 -me_range 16 -g 250 -keyint_min 25 -sc_threshold 40 -i_qfactor 0.71 $resolution_and_padding$ -r 22 -y $output_file$"
        recipe_audio_extraction = "ffmpeg -i $input_file$ -ar 48000 -ac 2 -y $output_file$"
        
        transcoder.execute(recipe, recipe_options.merge({:output_file => temp_video_output_file}))
        log.info "Video encoding done"
        
        if inspector.audio?
          # We have to use nero to encode the audio as ffmpeg doens't support HE-AAC yet
          transcoder.execute(recipe_audio_extraction, recipe_options.merge({:output_file => temp_audio_output_wav_file}))
          log.info "Audio extraction done"
        
          # Convert to HE-AAC
          %x(neroAacEnc -br #{encoding[:audio_bitrate_in_bits]} -he -if #{temp_audio_output_wav_file} -of #{temp_audio_output_file})
          log.info "Audio encoding done"
          log.info Time.now
        
          # Squash the audio and video together
          FileUtils.rm(enc_fn) if File.exists?(enc_fn) # rm, otherwise we end up with multiple video streams when we encode a few times!!
          %x(MP4Box -add #{temp_video_output_file}#video #{enc_fn})
          %x(MP4Box -add #{temp_audio_output_file}#audio #{enc_fn})
        
          # Interleave meta data
          %x(MP4Box -inter 500 #{enc_fn})
          log.info "Squashing done"
        else
          log.info "This video does't have an audio stream"
          FileUtils.mv(temp_video_output_file, enc_fn)
        end
        log.info Time.now
      else
        log.warn "Error: unknown encoding format given"
        Rog.log :error, "job##{job[:id]}: Couldn't encode #{encoding[:id]}. Unknown encoding format given."
      end
      
      log.info "Done encoding"
      
      # Now upload it to S3
      if File.exists?(enc_fn)
        Rog.log :info, "job##{job[:id]}: Success encoding #{encoding[:id]}. Uploading to S3."
        log.info "Uploading #{enc_fn}"
        begin
          S3VideoObject.store(encoding[:filename], open(enc_fn), :access => :public_read)        
        rescue
          Rog.log :error, "job##{job[:id]}: Couldn't upload file to S3, retrying"
          retry
        end
        FileUtils.rm enc_fn
        log.info "Done uploading"
        
        # Update the encoding data which will be returned to the server
        encoding[:status] = "success"
      else
        encoding[:status] = "error"
        Rog.log :info, "job##{job[:id]}: Couldn't upload #{encoding[:id]} to S3. To file #{enc_fn} doesn't exist."
        log.warn "Error: Cannot upload as #{enc_fn} does not exist"
      end
      
      # Seems like it was a success
      encoding[:status] = "success"
      encoding[:executed_commands] = transcoder.executed_commands
    rescue RVideo::TranscoderError => e
      encoding[:status] = "error"
      encoding[:executed_commands] = transcoder.executed_commands
      Rog.log :error, "job##{job[:id]}: Error transcoding #{encoding[:id]}: #{e.class} - #{e.message}"
      log.info "Unable to transcode file #{encoding[:id]}: #{e.class} - #{e.message}"
    end
  end
  
  log.info "All encodings complete!"
  Rog.log :info, "job##{job[:id]}: Complete!"
  FileUtils.rm raw_fn
  job[:encoding_time] = Time.now - begun_encoding
  return job
end

loop do
  sleep 3
  log.info "Checking for messages... #{Time.now}"
  next unless m = Queue.encodings.receive_message
  
  log.info "Got a message!"
  key = m.body
  log.info key
  m.delete
  # Maybe we should encase this in a begin rescue?
  job_result = encode_video(key,log)
    
  # log.warn "Panda returned an unexpected response"
end

# recipe = "ffmpeg -i $input_file$ -ar 22050 -ab 48 -vcodec h264 -f mp4 -b #{video[:video_bitrate]} -r #{inspector.fps} -s" 
# recipe = "ffmpeg -i $input_file$ -ar 22050 -ab 48 -f flv -b $video_bitrate$ -r $fps$ -s"

# using -an to disable audio for now
# recipe = "ffmpeg -i $input_file$ -an -f flv -b $video_bitrate$ -s $resolution$ -y $output_file$" 

# Some crazy h264 stuff
# ffmpeg -y -i matrix.mov -v 1 -threads 1 -vcodec h264 -b 500 -bt 175 -refs 2 -loop 1 -deblockalpha 0 -deblockbeta 0 -parti4x4 1 -partp8x8 1 -partb8x8 1 -me full -subq 6 -brdo 1 -me_range 21 -chroma 1 -slice 2 -max_b_frames 0 -level 13 -g 300 -keyint_min 30 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.7 -qmax 35 -max_qdiff 4 -i_quant_factor 0.71428572 -b_quant_factor 0.76923078 -rc_max_rate 768 -rc_buffer_size 244 -cmp 1 -s 720x304 -acodec aac -ab 64 -ar 44100 -ac 1 -f mp4 -pass 1 matrix-h264.mp4

# ffmpeg -y -i matrix.mov -v 1 -threads 1 -vcodec h264 -b 500 -bt 175 -refs 2 -loop 1 -deblockalpha 0 -deblockbeta 0 -parti4x4 1 -partp8x8 1 -partb8x8 1 -me full -subq 6 -brdo 1 -me_range 21 -chroma 1 -slice 2 -max_b_frames 0 -level 13 -g 300 -keyint_min 30 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.7 -qmax 35 -max_qdiff 4 -i_quant_factor 0.71428572 -b_quant_factor 0.76923078 -rc_max_rate 768 -rc_buffer_size 244 -cmp 1 -s 720x304 -acodec aac -ab 64 -ar 44100 -ac 1 -f mp4 -pass 2 matrix-h264.mp4

# max_b_frames option not working, need to upgrade to ffmpeg svn. 
# See: http://lists.mplayerhq.hu/pipermail/ffmpeg-user/2006-September/004186.html
# recipe = "ffmpeg -y -i $input_file$ -v 1 -threads 1 -vcodec h264 -b $video_bitrate$ -bt 175 -refs 2 -loop 1 -deblockalpha 0 -deblockbeta 0 -parti4x4 1 -partp8x8 1 -partb8x8 1 -me full -subq 6 -brdo 1 -me_range 21 -chroma 1 -slice 2 -max_b_frames 0 -level 13 -g 300 -keyint_min 30 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.7 -qmax 35 -max_qdiff 4 -i_quant_factor 0.71428572 -b_quant_factor 0.76923078 -rc_max_rate 768 -rc_buffer_size 244 -cmp 1 -s $resolution$ -acodec aac -ab $audio_sample_rate$ -ar 44100 -ac 1 -f mp4 -pass 1 $output_file$"
# recipe += "ffmpeg -y -i $input_file$ -v 1 -threads 1 -vcodec h264 -b $video_bitrate$ -bt 175 -refs 2 -loop 1 -deblockalpha 0 -deblockbeta 0 -parti4x4 1 -partp8x8 1 -partb8x8 1 -me full -subq 6 -brdo 1 -me_range 21 -chroma 1 -slice 2 -max_b_frames 0 -level 13 -g 300 -keyint_min 30 -sc_threshold 40 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.7 -qmax 35 -max_qdiff 4 -i_quant_factor 0.71428572 -b_quant_factor 0.76923078 -rc_max_rate 768 -rc_buffer_size 244 -cmp 1 -s $resolution$ -acodec aac -ab $audio_sample_rate$ -ar 44100 -ac 1 -f mp4 -pass 2 $output_file$"

# recipe = "ffmpeg -i $input_file$ -an -vcodec libx264 -b $video_bitrate$ -bt $video_bitrate$ -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.6 -qmin 10 -qmax 51 -qdiff 4 -coder 1 -flags +loop -cmp +chroma -partitions +parti4x4+partp8x8+partb8x8 -me hex -subq 5 -me_range 16 -g 250 -keyint_min 25 -sc_threshold 40 -i_qfactor 0.71 -s $resolution$ -y $output_file$"
# 2 pass encoding is slllloooowwwwwww
# recipe = "ffmpeg -y -i $input_file$ -an -pass 1 -vcodec libx264 -b $video_bitrate$ -flags +loop -cmp +chroma -partitions +parti4x4+partp8x8+partb8x8 -flags2 +mixed_refs -me umh -subq 5 -trellis 1 -refs 3 -bf 3 -b_strategy 1 -coder 1 -me_range 16 -g 250 -keyint_min 25 -sc_threshold 40 -i_qfactor 0.71 -bt $video_bitrate$k -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.8 -qmin 10 -qmax 51 -qdiff 4 $output_file$"
# recipe += "\nffmpeg -y -i $input_file$ -an -pass 2 -vcodec libx264 -b $video_bitrate$ -flags +loop -cmp +chroma -partitions +parti4x4+partp8x8+partb8x8 -flags2 +mixed_refs -me umh -subq 5 -trellis 1 -refs 3 -bf 3 -b_strategy 1 -coder 1 -me_range 16 -g 250 -keyint_min 25 -sc_threshold 40 -i_qfactor 0.71 -bt $video_bitrate$k -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.8 -qmin 10 -qmax 51 -qdiff 4 $output_file$"