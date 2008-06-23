require File.join( File.dirname(__FILE__), "..", "spec_helper" )

describe Video do
  before :each do
    @video = Video.new
  end
  
  it "should return correct API create response hash" do
    @video.key = 'abc'
    @video.create_response.should == {:video => {:id => 'abc'}}
  end
  
  # Old panda version tests
  # it "should have key after create" do
  #   @video.save
  #   @video.key.should_not be_nil
  # end
  # 
  # it "should have default status of empty after create" do
  #   @video.save
  #   @video.status.should == "empty"
  # end
  # 
  # it "should return 00:00 duration string for nil duration" do
  #   @video.duration_str.should == "00:00"
  # end
  # 
  # it "should return correct duration string" do
  #   @video = Video.new
  #   @video.duration = 5586000
  #   @video.duration_str.should == "93:06"
  # end
  # 
  # it "should be added to the job queue" do
  #   @video.save
  #   @video.should_receive(:send_status)
  #   job = @video.add_to_queue
  #   job.status.should == "queued"
  #   job.video_id.should == @video.id
  # end
  # 
  # it "should add encoding" do
  #   f = Format.create(:name => "Flash video", :code => "flv")
  #   quality = Quality.create(:format_id => f.id, :quality => "sd", :container => "flv", :width => 320, :height => 240, :position => 0)
  #   
  #   # Video only added if width is at least that of the quality
  #   @video.width = 320
  #   @video.save
  #   @video.add_encoding_for_quality(quality)
  #   
  #   enc = @video.encodings.first
  #   enc.quality_id.should == quality.id
  #   enc.status.should == "queued"
  # end
end