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
  end
  
  def setup_video
    # First part of action
    
    Video.stub!(:find).with("abc").and_return(@video)
    @video.should_receive(:filename=).with("abc.avi")
    FileUtils.should_receive(:mv).with(an_instance_of(String), "/tmp/abc.avi")
    @video.should_receive(:original_filename=).with("video.avi")
    
    # Next @video.process is called, this is where the interesting stuff happens, errors raised etc...
  end
  
  def post_video(format=:html)
    setup_video
    @c = multipart_post("/videos/abc/upload.#{format}", {:file => File.open(File.join( File.dirname(__FILE__), "video.avi"))})
  end
  
  it "should process valid video" do
    @video.should_receive(:process).and_return(true)
    @video.should_receive(:status=).with("original")
    @video.should_receive(:save)    
    post_video
    @c.status.should == 302
    @c.should redirect_to("http://localhost:4000/videos/abc/done")
  end
  
  it "should raise Video::NoFileSubmitted and return 404 if no file parameter is posted" do
    @c = post("/videos/abc/upload.html", {:iframe => "true"})
    # @status.should == 500
    @c.body.should match(/NoFileSubmitted/)
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
end