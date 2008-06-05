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

describe Videos, "valid action" do
  before(:each) do
    @video = mock(Video)
    @video.stub!(:token).and_return("123")
  end
  
  it "should return 200 if video is empty" do
    @video.should_receive(:empty?).and_return(true)
    Video.should_receive(:find_by_token).with("123").and_return(@video)
    get("/videos/123/valid.yaml")
    status.should == 200
  end
  
  it "should return 404 if video is not empty" do
    @video.should_receive(:empty?).and_return(false)
    Video.should_receive(:find_by_token).with("123").and_return(@video)
    get("/videos/123/valid.yaml")
    status.should == 404
  end
end

describe Videos, "process action" do
  before(:each) do
    @video = mock(Video)
    @video.stub!(:token).and_return("123")
    @filename = "vid.avi"
    @raw_filename = "raw.avi"
  end
  
  def setup_video
    @video.should_receive(:filename=).with("vid.avi")
    @video.should_receive(:empty?).and_return(true)
    @video.should_receive(:save_metadata).with({:metadata => :here})
    @video.should_receive(:save)
    
    @video.should_receive(:add_encodings)
    @video.should_receive(:add_to_queue).and_return(OpenStruct.new(:id => 999))
  end
  
  it "should return 200, add video to queue and set location header" do
    setup_video
    Video.should_receive(:find_by_token).with("123").and_return(@video)
    @video.stub!(:account).and_return(OpenStruct.new(:upload_redirect_url => "http://mysite.com/videos/done"))
    
    post("/videos/123/uploaded.yaml", {:filename => "vid.avi", :metadata => {:metadata => :here}.to_yaml})
    status.should == 200
    headers['Location'].should == "http://mysite.com/videos/done"
  end
  
  it "should return 200, add video to queue but not set location header if account.upload_redirect_url is blank" do
    setup_video
    Video.should_receive(:find_by_token).with("123").and_return(@video)
    @video.stub!(:account).and_return(OpenStruct.new(:upload_redirect_url => ""))
    
    post("/videos/123/uploaded.yaml", {:filename => "vid.avi", :metadata => {:metadata => :here}.to_yaml})
    status.should == 200
    headers['Location'].should_not == "http://mysite.com/videos/done"
  end
  
  it "should return 404 if video is not empty" do
    @video.should_receive(:empty?).and_return(false)
    Video.should_receive(:find_by_token).with("123").and_return(@video)
    post("/videos/123/uploaded.yaml")
    status.should == 404
  end
end