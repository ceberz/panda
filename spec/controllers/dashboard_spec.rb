require File.join(File.dirname(__FILE__), '..', 'spec_helper.rb')

describe Dashboard, "index" do
  before(:each) do
    @mock_queue = stub_everything("mock encode queue")
    @mock_query_result = stub_everything("mock query result")
    Video.stub!(:recent_encodings)
    Video.stub!(:queued_encodings)
    Video.stub!(:query).and_return(@mock_query_result)
    EncodeQueue.stub!(:new).and_return(@mock_queue)
  end
  
  it "should query recent and queued encodings" do
    Video.should_receive(:recent_encodings)
    Video.should_receive(:queued_encodings)
    
    dispatch_to(Dashboard, :index) do |controller| 
      controller.stub!(:render) 
      controller.stub!(:require_login)
    end
  end
  
  it "should query the job queue for length" do
    @mock_queue.should_recieve(:num_jobs).once
    
    dispatch_to(Dashboard, :index) do |controller| 
      controller.stub!(:render) 
      controller.stub!(:require_login)
    end
  end
  
  it "should check the number of queued jobs in the DB" do
    Video.should_receive(:query).once.with("['status' = 'queued']").and_return(@mock_query_result)
    @mock_query_result.should_receive(:size)
    
    dispatch_to(Dashboard, :index) do |controller| 
      controller.stub!(:render) 
      controller.stub!(:require_login)
    end
  end
end