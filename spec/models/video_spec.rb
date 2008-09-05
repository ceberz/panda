require File.join( File.dirname(__FILE__), "..", "spec_helper" )
require 'job_queue.rb'

describe Video do
  before :each do
    @video = mock_video
    
    Panda::Config.use do |p|
      p[:tmp_video_dir] = '/tmp'
      p[:state_update_url] = "http://localhost:4000/videos/$id/status"
      p[:upload_redirect_url] = "http://localhost:4000/videos/$id/done"
      p[:videos_domain] = "videos.pandastream.com"
      p[:thumbnail_height_constrain] = 126
    end
    
    class S3VideoObject; end
  end
  
  # Classification
  # ==============
  
  it "encoding? returns false if video is original" do
    @video.status = 'original'
    @video.encoding?.should be_false
  end
  
  it "queued? returns true iff video is in a queued state" do
    @video.status = "queued"
    @video.queued?.should be_true
    
    @video.status = "original"
    @video.queued?.should be_false
  end
  
  # Finders
  # =======
  
  it "self.all" do
    Video.should_receive(:query).with("['status' = 'original'] intersection ['created_at' != ''] sort 'created_at' desc", {:load_attrs=>true})
    
    Video.all
  end
  
  it "self.recent_videos" do
    Video.should_receive(:query).with("['status' = 'original']", :max_results => 10, :load_attrs => true)
    
    Video.recent_videos
  end
  
  it "self.recent_encodings" do
    Video.should_receive(:query).with("['status' = 'success']", :max_results => 10, :load_attrs => true)
    
    Video.recent_encodings
  end
  
  it "self.queued_encodings" do
    Video.should_receive(:query).with("['status' = 'processing' or 'status' = 'queued']", :load_attrs => true)
    
    Video.queued_encodings
  end
  
  it "self.next_job" do
    mocked_jobs = mock("jobs")
    mocked_param = mock("mocked_param")
    mocked_sqs_queue = mock("mocked sqs queue")
    mocked_sqs_queue.should_receive(:dequeue).once.with(mocked_param).and_return(mocked_jobs)
    JobQueue.should_receive(:new).and_return(mocked_sqs_queue)
    Video.next_job(mocked_param).should == mocked_jobs
  end
  
  it "self.delete_job" do
    mocked_sqs_queue = mock("mocked sqs queue")
    mocked_sqs_queue.should_receive(:delete).once.with("receipt")
    JobQueue.should_receive(:new).and_return(mocked_sqs_queue)
    Video.delete_job("receipt")
  end
  
  it "parent_video" do
    @video.parent = 'xyz'
    Video.should_receive(:find).with('xyz')
    
    @video.parent_video
  end
  
  it "encodings" do 
    Video.should_receive(:query).with("['parent' = 'abc']")
    @video.encodings
  end
  
  # Attr helpers
  # ============
  
  it "obliterate!" do
    S3VideoObject.should_receive(:delete).with('abc.mov')
    
    encoding = Video.new
    encoding.filename = 'abc.flv'
    S3VideoObject.should_receive(:delete).with('abc.flv')
    encoding.should_receive(:destroy!)
    
    @video.should_receive(:encodings).and_return([encoding])
    @video.should_receive(:destroy!)
    
    @video.obliterate!
  end
    
  it "tmp_filepath" do
    @video.tmp_filepath.should == '/tmp/abc.mov'
  end

  it "empty?" do
    @video.status = 'empty'
    @video.empty?.should be_true
  end
  
  it "should put video key into update_redirect_url" do
    @video.upload_redirect_url.should == "http://localhost:4000/videos/abc/done"
  end
  
  it "should put video key into state_update_url" do
    @video.state_update_url.should == "http://localhost:4000/videos/abc/status"
  end
  
  it "should return 00:00 duration string for nil duration" do
    @video.duration_str.should == "00:00"
  end
  
  it "should return correct duration string" do
    @video.duration = 5586000
    @video.duration_str.should == "93:06"
  end
  
  it "should return nil resolution if there is no width" do
    @video.width = nil
    @video.resolution.should be_nil
  end
  
  # def video_bitrate_in_bits
  # def audio_bitrate_in_bits
  
  it "screenshot" do
    @video.screenshot.should == 'abc.mov.jpg'
  end
  
  it "thumbnail" do
    @video.thumbnail.should == 'abc.mov_thumb.jpg'
  end
  
  it "screenshot_url" do
    @video.screenshot_url.should == "http://videos.pandastream.com/abc.mov.jpg"
  end
  
  it "thumbnail_url" do
    @video.thumbnail_url.should == "http://videos.pandastream.com/abc.mov_thumb.jpg"
  end
  
  # def set_encoded_at
  
  # Encding attr helpers
  # ====================
  
  it "url" do
    @video.url.should == "http://videos.pandastream.com/abc.mov"
  end
  
  it "should not reutrn embed_html for a parent/original video" do
    @video.status = 'original'
    @video.embed_html.should be_nil
  end
  
  it "embed_html" do
    @video.filename = 'abc.flv'
    @video.width = 320
    @video.height = 240
    @video.status = 'success'
    
    @video.embed_html.should == %(<embed src="http://videos.pandastream.com/flvplayer.swf" width="320" height="240" allowfullscreen="true" allowscriptaccess="always" flashvars="&displayheight=240&file=http://videos.pandastream.com/abc.flv&width=320&height=240&image=http://videos.pandastream.com/abc.flv.jpg" />)
  end
  
  # S3
  # ==
  
  it "should upload_to_s3" do
    File.should_receive(:open).with('/tmp/abc.mov').and_return(:fp)
    S3VideoObject.should_receive(:store).with('abc.mov', :fp, :access => :public_read).and_return(true)
    
    @video.upload_to_s3.should be_true
  end
  
  it "upload_to_s3 should retry uploading to S3 up to 6 times" do
    File.should_receive(:open).exactly(6).times.with('/tmp/abc.mov').and_return(:fp)
    S3VideoObject.should_receive(:store).with('abc.mov', :fp, :access => :public_read).exactly(6).times.and_raise(AWS::S3::S3Exception)
    
    lambda {@video.upload_to_s3}.should raise_error(AWS::S3::S3Exception)
  end
  
  it "should fetch_from_s3" do
    fp = mock(File)
    fp.stub!(:write)
    File.should_receive(:open).with('/tmp/abc.mov', 'w').and_yield(fp)
    S3VideoObject.should_receive(:stream).with('abc.mov').and_yield('chunk')
    
    @video.fetch_from_s3.should be_true
  end
  
  it "fetch_from_s3 should retry fetching from S3 up to 6 times" do
    fp = mock(File)
    fp.stub!(:write)
    File.should_receive(:open).exactly(6).times.with('/tmp/abc.mov', 'w').and_yield(fp)
    S3VideoObject.should_receive(:stream).exactly(6).with('abc.mov').and_raise(AWS::S3::S3Exception)
    
    lambda {@video.fetch_from_s3}.should raise_error(AWS::S3::S3Exception)
  end
  
  it "should capture_thumbnail_and_upload_to_s3" do
    inspector = mock(RVideo::Inspector)
    inspector.should_receive(:capture_frame).with('50%', '/tmp/abc.mov.jpg')
    RVideo::Inspector.should_receive(:new).with(:file => '/tmp/abc.mov').and_return(inspector)
    
    gd = mock(GDResize)
    gd.should_receive(:resize).with('/tmp/abc.mov.jpg', '/tmp/abc.mov_thumb.jpg', [168,126]) # Dimensions based on thumbnail_height_constrain of 126
    GDResize.should_receive(:new).and_return(gd)
    
    File.should_receive(:open).with('/tmp/abc.mov.jpg').and_return(:fp)
    S3VideoObject.should_receive(:store).with('abc.mov.jpg', :fp, :access => :public_read)
    
    File.should_receive(:open).with('/tmp/abc.mov_thumb.jpg').and_return(:fp)
    S3VideoObject.should_receive(:store).with('abc.mov_thumb.jpg', :fp, :access => :public_read)
    
    @video.capture_thumbnail_and_upload_to_s3.should be_true
  end
  
  # Uploads
  # =======
  
  it "should process" do
    @video.should_receive(:valid?)
    @video.should_receive(:read_metadata)
    @video.should_receive(:upload_to_s3)
    @video.should_receive(:add_to_queue)
    
    @video.process
  end
  
  it "valid? should raise NotValid if video is not empty" do
    @video.status = 'original'
    lambda {@video.valid?}.should raise_error(Video::NotValid)
  end
  
  it "valid? should return true if video is empty" do
    @video.status = 'empty'
    @video.valid?.should be_true
  end
  
  # def read_metadata
  
  it "should enqueue each profile job, marked as queued, in the SQS queue" do
    profile = mock_profile
    Profile.should_receive(:query).twice.and_return([mock_profile])
    Video.should_receive(:query).with("['parent' = 'abc'] intersection ['profile' = 'profile1']").and_return([])
    # We didn't find a video, so the method will create one now
    
    encoding = Video.new('xyz')
    encoding.should_receive(:status=).with("queued")
    encoding.should_receive(:filename=).with("xyz.flv")
    
    # Attrs from the parent video
    encoding.should_receive(:parent=).with("abc")
    encoding.should_receive(:original_filename=).with("original_filename.mov")
    encoding.should_receive(:duration=).with(100)
    
    # Attrs from the profile
    encoding.should_receive(:profile=).with("profile1")
    encoding.should_receive(:profile_title=).with("Flash video HI")
    
    encoding.should_receive(:container=).with("flv")
    encoding.should_receive(:width=).with(480)
    encoding.should_receive(:height=).with(360)
    encoding.should_receive(:video_bitrate=).with(400)
    encoding.should_receive(:fps=).with(24)
    encoding.should_receive(:audio_bitrate=).with(48)
    encoding.should_receive(:player=).with("flash")
    
    encoding.should_receive(:save)
    
    Video.should_receive(:new).and_return(encoding)
    
    mocked_sqs_queue = mock("mocked sqs queue")
    mocked_sqs_queue.should_receive(:enqueue).once.with(encoding)
    JobQueue.should_receive(:new).once.and_return(mocked_sqs_queue)
    
    @video.add_to_queue
  end
  
  # Also test create_encoding_for_profile(p) and find_encoding_for_profile(p)
  it "should create profiles when add_to_queue is called" do
    profile = mock_profile
    Profile.should_receive(:query).twice.and_return([mock_profile])
    Video.should_receive(:query).with("['parent' = 'abc'] intersection ['profile' = 'profile1']").and_return([])
    # We didn't find a video, so the method will create one now
    
    encoding = Video.new('xyz')
    encoding.should_receive(:status=).with("queued")
    encoding.should_receive(:filename=).with("xyz.flv")
    
    # Attrs from the parent video
    encoding.should_receive(:parent=).with("abc")
    encoding.should_receive(:original_filename=).with("original_filename.mov")
    encoding.should_receive(:duration=).with(100)
    
    # Attrs from the profile
    encoding.should_receive(:profile=).with("profile1")
    encoding.should_receive(:profile_title=).with("Flash video HI")
    
    encoding.should_receive(:container=).with("flv")
    encoding.should_receive(:width=).with(480)
    encoding.should_receive(:height=).with(360)
    encoding.should_receive(:video_bitrate=).with(400)
    encoding.should_receive(:fps=).with(24)
    encoding.should_receive(:audio_bitrate=).with(48)
    encoding.should_receive(:player=).with("flash")
    
    encoding.should_receive(:save)
    
    Video.should_receive(:new).and_return(encoding)

    mocked_sqs_queue = stub_everything("mocked sqs queue")
    JobQueue.should_receive(:new).once.and_return(mocked_sqs_queue)
    
    
    @video.add_to_queue
  end

  # def show_response
  
  it "should return correct API create response hash" do
    @video.create_response.should == {:video => {:id => 'abc'}}
  end
  
  # Notifications
  # =============
  
  it "should return true if the current time is past the encoding's notification wait period" do
    t = Time.now
    encoding = mock_encoding_flv_flash(:last_notification_at => t - 50, :notification => 1)
    # Default notification_frequency is 1 second
    encoding.time_to_send_notification?.should == true
  end
  
  it "should return false if the current time is not past the encoding's notification wait period" do
    t = Time.now
    encoding = mock_encoding_flv_flash(:last_notification_at => t, :notification => 10)
    Panda::Config[:notification_frequency] = 50
    encoding.time_to_send_notification?.should == false
  end
  
  it "should send notification to client" do
    encoding = mock_encoding_flv_flash
    encoding.stub!(:parent_video).and_return(@video)
    @video.should_receive(:send_status_update_to_client)
    
    encoding.should_receive(:last_notification_at=).with(an_instance_of(Time))
    encoding.should_receive(:notification=).with("success")
    encoding.should_receive(:save)
    
    encoding.send_notification
  end
  
  it "should increment notification retry count if sending the notification fails" do
    encoding = mock_encoding_flv_flash
    encoding.stub!(:parent_video).and_return(@video)
    @video.should_receive(:send_status_update_to_client).and_raise(Video::NotificationError)
    
    encoding.should_receive(:last_notification_at=).with(an_instance_of(Time))
    encoding.should_receive(:notification).twice().and_return(1)
    encoding.should_receive(:notification=).with(2)
    encoding.should_receive(:save)
    
    lambda {encoding.send_notification}.should raise_error(Video::NotificationError)
  end
  
  it "should only allow notifications of encodings to be sent" do
    lambda {@video.send_notification}.should raise_error(StandardError)
  end
  
  # it "should send_status_update_to_client" do
    
  
  # Encoding
  # ========
  
  # def ffmpeg_resolution_and_padding(inspector)
  
  it "should constrain video and preserve aspect ratio (no cropping or pillarboxing) if a 4:3 video is encoded with a 16:9 profile" do
    parent_video = mock_video({:width => 640, :height => 480})
    encoding = mock_encoding_flv_flash({:width => 640, :height => 360})
    encoding.should_receive(:parent_video).twice.and_return(parent_video)
    # We also need to then update the encoding's sizing to the new width
    encoding.should_receive(:width=).with(480)
    encoding.should_receive(:save)
    encoding.ffmpeg_resolution_and_padding_no_cropping.should == "-s 480x360 "
  end
  
  it "should constrain video if a 16:9 video is encoded with a 16:9 profile" do
    parent_video = mock_video({:width => 1280, :height => 720})
    encoding = mock_encoding_flv_flash({:width => 640, :height => 360})
    encoding.should_receive(:parent_video).twice.and_return(parent_video)
    encoding.ffmpeg_resolution_and_padding_no_cropping.should == "-s 640x360 "
  end
  
  it "should letterbox if a 2.40:1 (848x352) video is encoded with a 16:9 profile" do
    parent_video = mock_video({:width => 848, :height => 352})
    encoding = mock_encoding_flv_flash({:width => 640, :height => 360})
    encoding.should_receive(:parent_video).twice.and_return(parent_video)
    encoding.ffmpeg_resolution_and_padding_no_cropping.should == "-s 640x264 -padtop 48 -padbottom 48"
  end
  
  it "should return correct recipe_options hash" do
    encoding = mock_encoding_flv_flash
    encoding.should_receive(:parent_video).twice.and_return(@video)
    encoding.recipe_options('/tmp/abc.mov', '/tmp/xyz.flv').should eql_hash(
      {
        :input_file => '/tmp/abc.mov',
        :output_file => '/tmp/xyz.flv',
        :container => 'flv',
        :video_codec => '',
        :video_bitrate_in_bits => (400*1024).to_s, 
        :fps => 24,
        :audio_codec => '', 
        :audio_bitrate => '48', 
        :audio_bitrate_in_bits => (48*1024).to_s, 
        :audio_sample_rate => '', 
        :resolution => '480x360',
        :resolution_and_padding => "-s 480x360 " # encoding.ffmpeg_resolution_and_padding
      }
    )
  end
    
  it "should call encode_flv_flash when encoding an flv for the flash player" do
    encoding = mock_encoding_flv_flash
    encoding.stub!(:parent_video).and_return(@video)
    @video.should_receive(:fetch_from_s3)
  
    encoding.should_receive(:status=).with("processing")
    encoding.should_receive(:save).twice
    encoding.should_receive(:encode_flv_flash)
  
    encoding.should_receive(:upload_to_s3)
    encoding.should_receive(:capture_thumbnail_and_upload_to_s3)
    
    encoding.should_receive(:notification=).with(0)
    encoding.should_receive(:status=).with("success")
    encoding.should_receive(:encoded_at=).with(an_instance_of(Time))
    encoding.should_receive(:encoding_time=).with(an_instance_of(Integer))
    # encoding.should_receive(:save) expected twice above
    
    FileUtils.should_receive(:rm).with('/tmp/xyz.flv')
    FileUtils.should_receive(:rm).with('/tmp/abc.mov')
  
    encoding.encode
  end
  
  it "should set the encoding's status to error if the video fails to encode correctly" do
    encoding = mock_encoding_flv_flash
    encoding.stub!(:parent_video).and_return(@video)
    @video.should_receive(:fetch_from_s3)
  
    encoding.should_receive(:status=).with("processing")
    encoding.should_receive(:save).twice
    encoding.should_receive(:encode_flv_flash).and_raise(RVideo::TranscoderError)
    encoding.should_receive(:notification=).with(0)
    encoding.should_receive(:status=).with("error")
    # encoding.should_receive(:save) expected twice above
    FileUtils.should_receive(:rm).with('/tmp/abc.mov')
  
    lambda {encoding.encode}.should raise_error(RVideo::TranscoderError)
  end

  it "should run correct ffmpeg command to encode to an flv for the flash player" do
    encoding = mock_encoding_flv_flash
    encoding.stub!(:parent_video).and_return(@video)
    transcoder = mock(RVideo::Transcoder)
    RVideo::Transcoder.should_receive(:new).and_return(transcoder)
    
    transcoder.should_receive(:execute).with(
      "ffmpeg -i $input_file$ -ar 22050 -ab $audio_bitrate$k -f flv -b $video_bitrate_in_bits$ -r 24 $resolution_and_padding$ -y $output_file$\nflvtool2 -U $output_file$", nil)
    encoding.should_receive(:recipe_options).with('/tmp/abc.mov', '/tmp/xyz.flv')
    
    encoding.encode_flv_flash
  end
  
  it "should run correct ffmpeg command to encode to an mp4 for the flash player" do
    encoding = mock_encoding_mp4_aac_flash
    encoding.stub!(:parent_video).and_return(@video)
    transcoder = mock(RVideo::Transcoder)
    RVideo::Transcoder.should_receive(:new).and_return(transcoder)
    
    transcoder.should_receive(:execute).with(
      "ffmpeg -i $input_file$ -b $video_bitrate_in_bits$ -an -vcodec libx264 -rc_eq 'blurCplx^(1-qComp)' -qcomp 0.6 -qmin 10 -qmax 51 -qdiff 4 -coder 1 -flags +loop -cmp +chroma -partitions +parti4x4+partp8x8+partb8x8 -me hex -subq 5 -me_range 16 -g 250 -keyint_min 25 -sc_threshold 40 -i_qfactor 0.71 $resolution_and_padding$ -r 24 -threads 4 -y $output_file$", nil) # No need to test the 2nd parameter for recepie options which is tested in another test
    encoding.should_receive(:recipe_options).with('/tmp/abc.mov', '/tmp/xyz.mp4.temp.video.mp4')

    # Testing separate audio extraction and encoding for flash h264
    transcoder.should_receive(:execute).with(
      "ffmpeg -i $input_file$ -ar 48000 -ac 2 -y $output_file$", nil)
    encoding.should_receive(:recipe_options).with('/tmp/abc.mov', '/tmp/xyz.mp4.temp.audio.wav')

    # rm video file before we use MP4Box, otherwise we end up with multiple AV streams if the videos has been encoded more than once!
    File.should_receive(:exists?).with('/tmp/xyz.mp4').and_return(true)
    FileUtils.should_receive(:rm).with('/tmp/xyz.mp4')
    
    encoding.encode_mp4_aac_flash
  end
  
  it "should run correct ffmpeg command to encode to an unknown format" do
    encoding = mock_encoding_flv_flash
    encoding.stub!(:parent_video).and_return(@video)
    transcoder = mock(RVideo::Transcoder)
    RVideo::Transcoder.should_receive(:new).and_return(transcoder)
    
    transcoder.should_receive(:execute).with(
      "ffmpeg -i $input_file$ -f $container$ -vcodec $video_codec$ -b $video_bitrate_in_bits$ -ar $audio_sample_rate$ -ab $audio_bitrate$k -acodec $audio_codec$ -r 24 $resolution_and_padding$ -y $output_file$", nil)
    encoding.should_receive(:recipe_options).with('/tmp/abc.mov', '/tmp/xyz.flv')
    
    encoding.encode_unknown_format
  end
  
  private
  
    def mock_profile
      Profile.new("profile1", 
        {
          :title => "Flash video HI", 
          :container => "flv", 
          :video_bitrate => 400, 
          :audio_bitrate => 48, 
          :width => 480, 
          :height => 360, 
          :fps => 24, 
          :position => 1, 
          :player => "flash"
        }
      )
    end
  
  def mock_video(attrs={})
    enc = Video.new("abc", 
      {
        :status => 'original',
        :filename => 'abc.mov',
        :original_filename => 'original_filename.mov',
        :duration => 100,
        :video_codec => 'mp4',
        :video_bitrate => 400, 
        :fps => 24,
        :audio_codec => 'aac', 
        :audio_bitrate => 48, 
        :width => 480,
        :height => 360
      }.merge(attrs)
    )
  end
  
  def mock_encoding_flv_flash(attrs={})
    enc = Video.new('xyz', 
      {
        :status => 'queued',
        :filename => 'xyz.flv',
        :container => 'flv',
        :player => 'flash',
        :video_codec => '',
        :video_bitrate => 400, 
        :fps => 24,
        :audio_codec => '', 
        :audio_bitrate => 48, 
        :width => 480,
        :height => 360
      }.merge(attrs)
    )
  end
  
  def mock_encoding_mp4_aac_flash(attrs={})
    enc = Video.new('xyz', 
      {
        :status => 'queued',
        :filename => 'xyz.mp4',
        :container => 'mp4',
        :player => 'flash',
        :video_codec => '',
        :video_bitrate => 400, 
        :fps => 24,
        :audio_codec => 'aac', 
        :audio_bitrate => 48, 
        :width => 480,
        :height => 360
      }
    )
  end
  
  def mock_encoding_unknown_format(attrs={})
    enc = Video.new('xyz', 
      {
        :status => 'queued',
        :filename => 'xyz.xxx',
        :container => 'xxx',
        :player => 'someplayer',
        :video_codec => '',
        :video_bitrate => 400, 
        :fps => 24,
        :audio_codec => 'yyy', 
        :audio_bitrate => 48, 
        :width => 480,
        :height => 360
      }
    )
  end
end