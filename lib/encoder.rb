# WARNING: This code is procedural bollocks!
# merb -r "panda/lib/encoder.rb"

# Set hostname should probably be in the AMI startup script
# %x(set_hostname)

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

# require 'log4r'
# include Log4r
# 
# log = Logger.new 'encqlog'
# fileo = FileOutputter.new('fileOutputter', :filename => File.join(File.dirname(__FILE__), 'encoder.log'), :trunc => false)
# log.add fileo
# log.level = Log4r::DEBUG

Merb.logger.info 'Encoder awake!'

# New remote logger

# require 'rog'
# Rog.prefix = "Encoder##{HOSTNAME}"
# Rog.host = PANDA_LOG_SERVER
# Rog.port = 3333
# Merb.logger.info "Panda Encoder app awake"
q = SQS.get_queue(:name => Panda::Config[:sqs_encoding_queue])

loop do
  sleep 3
  Merb.logger.info "Checking for messages... #{Time.now}"
  next unless m = q.receive_message
  
  Merb.logger.info "Got a message!"
  key = m.body
  Merb.logger.info key
  m.delete
  # Maybe we should encase this in a begin rescue?
  begin
    video = Video.find(key)
  rescue Amazon::SDB::RecordNotFoundError
    Merb.logger.info "Couldn't find video item with key #{key}. Discarding message."
  else
    job_result = video.encode
  end
    
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