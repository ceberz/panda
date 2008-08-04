# merb -r "panda/lib/encoder.rb"

Merb.logger.info 'Encoder awake!'

AWS::S3::Base.disconnect! # Only connect to S3 when we need to

loop do
  sleep 3
  Merb.logger.debug "Checking for messages... #{Time.now}"
  if video = Video.next_job
    begin
      # Wait for stuff to show up on S3 and SimpleDB
      sleep 10
      
      AWS::S3::Base.establish_connection!(
        :access_key_id     => Panda::Config[:access_key_id],
        :secret_access_key => Panda::Config[:secret_access_key]
      )
      
      video.encode
      AWS::S3::Base.disconnect!
    rescue  
      begin
        AWS::S3::Base.disconnect!
        ErrorSender.log_and_email("encoding error", "Error encoding #{video.key}

#{$!}

PARENT ATTRS

#{"="*60}\n#{video.parent.attributes.to_h.to_yaml}\n#{"="*60}

ENCODING ATTRS

#{"="*60}\n#{video.attributes.to_h.to_yaml}\n#{"="*60}")
      rescue
        Merb.logger.error "Error sending error using ErrorSender.log_and_email - very erroneous! (#{$!})"
      end
    end
  end
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