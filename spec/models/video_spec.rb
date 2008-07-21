require File.join( File.dirname(__FILE__), "..", "spec_helper" )

describe Video do
  before :each do
    @video = mock_video
    
    Panda::Config.use do |p|
      p[:tmp_video_dir] = '/tmp'
      p[:state_update_url] = "http://localhost:4000/videos/$id/status"
      p[:upload_redirect_url] = "http://localhost:4000/videos/$id/done"
      p[:videos_domain] = "videos.pandastream.com"
    end
    
    class S3VideoObject; end
  end
  
  # Classification
  # ==============
  
  it "encoding? returns false if video is original" do
    @video.status = 'original'
    @video.encoding?.should be_false
  end
  
  # Finders
  # =======
  
  it "self.all" do
    Video.should_receive(:query).with("['status' = 'original']")
    
    Video.all
  end
  
  it "self.recent_videos" do
    Video.should_receive(:query).with("['status' = 'original']", :max_results => 10, :load_attrs => true)
    
    Video.recent_videos
  end
  
  it "self.recent_encodings" do
    Video.should_receive(:query).with("['encoded_at_desc' > '0'] intersection ['status' = 'success']", :max_results => 10, :load_attrs => true)
    
    Video.recent_encodings
  end
  
  it "self.queued_encodings" do
    Video.should_receive(:query).with("['status' = 'processing' or 'status' = 'queued']", :load_attrs => true)
    
    Video.queued_encodings
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
    gd.should_receive(:resize).with('/tmp/abc.mov.jpg', '/tmp/abc.mov_thumb.jpg', [96,96])
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
  
  it "should create profiles when add_to_queue is called" do
    profile = mock_profile
    Profile.should_receive(:query).twice.and_return([mock_profile])
    Video.should_receive(:query).with("['parent' = 'abc'] intersection ['profile' = 'profile1']").and_return([])
    # We didn't find a video, so the method will create one now
    
    encoding = Video.new
    encoding.should_receive(:save)
    Video.should_receive(:new).and_return(encoding)
    
    @video.add_to_queue
  end

  # def show_response
  
  it "should return correct API create response hash" do
    @video.create_response.should == {:video => {:id => 'abc'}}
  end
  
  # def send_status
  
  # Encoding
  # ========
  
  # def ffmpeg_resolution_and_padding(inspector)
  
  # it "should run correct encoding commands for a valid video" do
  #   encoding = mock_encoding
  #   @video.should_receive(:fetch_from_s3)
  #   @video.should_receive(:encodings).and_return([encoding])
  #   encoding.should_receive(:status=).with("processing")
  #   encoding.should_receive(:save)
  #   
  #   inspector = mock(RVideo::Inspector)
  #   inspector.should_receive(:width).and_return(480)
  #   inspector.should_receive(:height).and_return(360)
  #   RVideo::Inspector.should_receive(:new).with(:file => @video.tmp_filepath).and_return(inspector)
  #   
  #   transcoder = mock(RVideo::Transcoder)
  #   transcoder.should_receive(:execute).with(
  #     "ffmpeg -i $input_file$ -ar 22050 -ab $audio_bitrate$k -f flv -b $video_bitrate_in_bits$ -r 22 $resolution_and_padding$ -y $output_file$",
  #     {
  #       :input_file => '/tmp/abc.mov',
  #       :output_file => '/tmp/xyz.flv', 
  #       :container => 'flv',
  #       :video_bitrate => 400,
  #       :video_bitrate_in_bits => (400*1024).to_s, 
  #       :fps => 24,
  #       :audio_codec => '', 
  #       :audio_bitrate => 48 
  #       :audio_bitrate_in_bits => (48*1024).to_s, 
  #       :audio_sample_rate => '', 
  #       :resolution => '480x360',
  #       :resolution_and_padding => "-s 480x360 " # encoding.ffmpeg_resolution_and_padding
  #     }
  #   )
  #   RVideo::Transcoder.should_receive(:new).and_return(transcoder)
  #   
  #   @video.should_receive(:capture_thumbnail_and_upload_to_s3)
  # 
  # end
#   
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
        :video_codec => '',
        :video_bitrate => 400, 
        :fps => 24,
        :audio_codec => '', 
        :audio_bitrate => 48, 
        :width => 480,
        :height => 360
      }
    )
  end
  
  # def mock_encoding(attrs={})
  #   enc = Video.new('xyz', 
  #     {
  #       :status => 'queued',
  #       :filename => 'xyz.flv',
  #       :container => 'flv',
  #       :player => 'flash',
  #       :video_codec => '',
  #       :video_bitrate => 400, 
  #       :fps => 24,
  #       :audio_codec => '', 
  #       :audio_bitrate => 48, 
  #       :width => 480,
  #       :height => 360
  #     }
  #   )
  # end
end