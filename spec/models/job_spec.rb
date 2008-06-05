require File.join( File.dirname(__FILE__), "..", "spec_helper" )

describe Job do

  it "should should be next in queue if latest job" do
    video = Video.create
    job = video.add_to_queue
    Job.find_next_job.should == job
  end
end