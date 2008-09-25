require File.join(File.dirname(__FILE__), '..', 'spec_helper.rb')

# describe "Videos Controller", "index action" do
#   before(:each) do
#     @controller = Videos.build(fake_request)
#     @controller.dispatch('index')
#   end
#   
#   it "should return video details in yaml" do
# 
#   end
# end
# 
# describe Videos, "show action" do
#   before(:each) do
#     # @controller = Videos.build(fake_request)
#     # @controller[:params][:id] = "123"
#     # @controller.dispatch('show')
#   end
#   
#   it "should return video details in yaml" do
#       # controller.stub!(:render)
#       # puts body.to_yaml
#       # puts status
#       # puts headers
#       # puts controller.instance_variables
#     video = Video.create
#     Video.should_receive(:find_by_token).with(video.token)
#     get("/videos/#{video.token}.yaml")
#     # puts controller.inspect
#     # puts response.inspect
#     # status.should == 404
#     controller.should be_success
#     # puts @controller.methods.sort
#   end
# end

describe Videos, "form action" do
  before(:each) do
    @video = Video.new
    @video.key = 'abc'
  end
  
  it "should return a nice error when the video can't be found" do
    Video.should_receive(:find).with('qrs').and_raise(Amazon::SDB::RecordNotFoundError)
    @c = get("/videos/qrs/form")
    @c.body.should match(/RecordNotFoundError/)
  end
end

describe Videos, "upload action" do
  before(:each) do
    @video = Video.new
    @video.key = 'abc'
    @video.filename = 'abc.avi'
    
    Panda::Config.use do |p|
      p[:tmp_video_dir] = '/tmp'
      p[:state_update_url] = "http://localhost:4000/videos/$id/status"
      p[:upload_redirect_url] = "http://localhost:4000/videos/$id/done"
      p[:videos_domain] = "videos.pandastream.com"
    end
    
    class S3VideoObject; end
    
    @video_upload_url = "/videos/abc/upload.html"
    @video_upload_params = {:file => File.open(File.join( File.dirname(__FILE__), "video.avi"))}
  end
  
  def setup_video
    # First part of action
    
    Video.stub!(:find).with("abc").and_return(@video)
    @video.should_receive(:filename=).with("abc.avi")
    FileUtils.should_receive(:mv).with(an_instance_of(String), "/tmp/abc.avi")
    @video.should_receive(:original_filename=).with("video.avi")
    FileUtils.stub!(:rm)
    
    # Next @video.process is called, this is where the interesting stuff happens, errors raised etc...
  end
  
  it "should process valid video" do
    setup_video
    @video.should_receive(:process).and_return(true)
    @video.should_receive(:status=).with("original")
    @video.should_receive(:save)   
     
    @c = multipart_post(@video_upload_url, @video_upload_params) do |controller|
      controller.should_receive(:redirect).with("http://localhost:4000/videos/abc/done")
    end
  end
  
  # Video::NotValid / 404
  
  it "should return 404 when processing fails with Video::NotValid" do 
    setup_video
    @video.should_receive(:process).and_raise(Video::NotValid)
    @c = multipart_post(@video_upload_url, @video_upload_params)
    @c.body.should match(/NotValid/)
    @c.status.should == 404
  end
  
  # Amazon::SDB::RecordNotFoundError
  
  it "should raise RecordNotFoundError and return 404 when no record is found in SimpleDB" do 
    Video.stub!(:find).with("abc").and_raise(Amazon::SDB::RecordNotFoundError)
    @c = multipart_post(@video_upload_url, @video_upload_params)
    @c.body.should match(/RecordNotFoundError/)
    @c.status.should == 404
  end
  
  # Videos::NoFileSubmitted
  
  it "should raise Video::NoFileSubmitted and return 500 if no file parameter is posted" do
    @c = post("/videos/abc/upload.html")
    @c.body.should match(/NoFileSubmitted/)
    @c.status.should == 500
  end
  
  # InternalServerError
  
  it "should raise InternalServerError and return 500 if an unknown exception is raised" do
    Video.stub!(:find).with("abc").and_raise(RuntimeError)
    @c = multipart_post(@video_upload_url, @video_upload_params)
    @c.body.should match(/InternalServerError/)
    @c.status.should == 500
  end
  
  # Test iframe=true option with InternalServerError
  
  it "should reutrn error json inside a <textarea>" do
    Video.stub!(:find).with("abc").and_raise(RuntimeError)
    @c = multipart_post(@video_upload_url, @video_upload_params.merge({:iframe => true}))
    puts @c.body
    @c.body.should == %(<textarea>{"error": "InternalServerError"}</textarea>)
    @c.status.should == 500
  end
  
  # it "should return 200, add video to queue and set location header" do
  #   setup_video
  #   Video.should_receive(:find_by_token).with("123").and_return(@video)
  #   @video.stub!(:account).and_return(OpenStruct.new(:upload_redirect_url => "http://mysite.com/videos/done"))
  #   
  #   post("/videos/123/uploaded.yaml", {:filename => "vid.avi", :metadata => {:metadata => :here}.to_yaml})
  #   status.should == 200
  #   headers['Location'].should == "http://mysite.com/videos/done"
  # end
  
  # it "should return 200, add video to queue but not set location header if account.upload_redirect_url is blank" do
  #   setup_video
  #   Video.should_receive(:find_by_token).with("123").and_return(@video)
  #   @video.stub!(:account).and_return(OpenStruct.new(:upload_redirect_url => ""))
  #   
  #   post("/videos/123/uploaded.yaml", {:filename => "vid.avi", :metadata => {:metadata => :here}.to_yaml})
  #   status.should == 200
  #   headers['Location'].should_not == "http://mysite.com/videos/done"
  # end
  
  # it "should return 404 if video is not empty" do
  #   @video.should_receive(:empty?).and_return(false)
  #   Video.should_receive(:find_by_token).with("123").and_return(@video)
  #   post("/videos/123/uploaded.yaml")
  #   status.should == 404
  # end
  
  it "should delete the local copy of the video after upload to S3" do
    setup_video
    @video.should_receive(:process).ordered.and_return(true)
    @video.should_receive(:status=).ordered.with("original")
    @video.should_receive(:save).ordered
    
    FileUtils.should_receive(:rm).ordered.with(@video.tmp_filepath)   
     
    @c = multipart_post(@video_upload_url, @video_upload_params) do |controller|
      controller.should_receive(:redirect).with("http://localhost:4000/videos/abc/done")
    end
  end
end